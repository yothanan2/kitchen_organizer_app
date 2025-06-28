import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'providers.dart'; // Import our central providers file

// A helper widget for displaying unit names efficiently.
class UnitNameWidget extends ConsumerWidget {
  final String? docId;
  const UnitNameWidget({super.key, this.docId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (docId == null || docId!.isEmpty) {
      return const Text('', style: TextStyle(fontStyle: FontStyle.italic));
    }
    final unitsMapAsync = ref.watch(unitsMapProvider);
    return unitsMapAsync.when(
      data: (unitsMap) => Text(unitsMap[docId] ?? 'N/A'),
      loading: () => const Text('...'),
      error: (_, __) => const Text('?'),
    );
  }
}

// A helper widget for displaying supplier names efficiently.
class SupplierNameWidget extends ConsumerWidget {
  final String? docId;
  const SupplierNameWidget({super.key, this.docId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (docId == null || docId!.isEmpty) {
      return const SizedBox.shrink();
    }
    final suppliersMapAsync = ref.watch(suppliersMapProvider);
    return suppliersMapAsync.when(
      data: (suppliersMap) => Text(
        'Supplier: ${suppliersMap[docId] ?? 'Unknown'}',
        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}


// The main screen is a ConsumerStatefulWidget to manage the TextEditingControllers.
class StaffInventoryCountScreen extends ConsumerStatefulWidget {
  const StaffInventoryCountScreen({super.key});

  @override
  ConsumerState<StaffInventoryCountScreen> createState() => _StaffInventoryCountScreenState();
}

class _StaffInventoryCountScreenState extends ConsumerState<StaffInventoryCountScreen> {
  // The state of this screen now directly manages the controllers.
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveAllCounts() async {
    setState(() => _isLoading = true);

    final firestore = ref.read(firestoreProvider);
    final batch = firestore.batch();

    _controllers.forEach((docId, controller) {
      final newQuantity = num.tryParse(controller.text);
      if (newQuantity != null) {
        batch.update(firestore.collection('inventoryItems').doc(docId), {
          'quantityOnHand': newQuantity,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    });

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All counts saved successfully!')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save counts: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // We watch the simplified provider that only groups by location.
    final inventoryGroupsAsync = ref.watch(inventoryGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Inventory Count'),
        actions: [
          _isLoading
              ? const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white)))
              : IconButton(icon: const Icon(Icons.save), onPressed: _saveAllCounts, tooltip: 'Save All Counts'),
        ],
      ),
      body: inventoryGroupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (groups) {
          if (groups.isEmpty) {
            return const Center(child: Text('No inventory items have been created.'));
          }

          // CORRECTED: This now correctly expands the simplified map structure.
          final allItems = groups.values.expand((list) => list).toList();

          // Initialize controllers for any new items that appear in the list.
          for (final item in allItems) {
            if (!_controllers.containsKey(item.id)) {
              final initialValue = (item.data() as Map<String, dynamic>)['quantityOnHand']?.toString() ?? '0';
              _controllers[item.id] = TextEditingController(text: initialValue);
            }
          }

          final sortedLocations = groups.keys.toList()..sort();
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: sortedLocations.length,
            itemBuilder: (context, index) {
              final locationName = sortedLocations[index];
              final items = groups[locationName]!;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  // REMOVED: The PageStorageKey that was causing the conflict has been removed.
                  title: Text(locationName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  initiallyExpanded: true,
                  // MODIFIED: We no longer have the category sub-grouping and map directly to the item tiles.
                  children: items.map((itemDoc) {
                    final controller = _controllers[itemDoc.id];
                    return controller != null
                        ? _InventoryItemTile(key: ValueKey(itemDoc.id), itemDoc: itemDoc, controller: controller)
                        : const SizedBox.shrink();
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// The tile is a stateless widget that receives its controller.
class _InventoryItemTile extends ConsumerWidget {
  final DocumentSnapshot itemDoc;
  final TextEditingController controller;

  const _InventoryItemTile({super.key, required this.itemDoc, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = itemDoc.data() as Map<String, dynamic>;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['itemName'] ?? 'No Name', style: const TextStyle(fontSize: 16)),
                SupplierNameWidget(docId: data['supplier']),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: TextFormField(
              controller: controller, // Use the controller passed from the parent.
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              decoration: InputDecoration(
                suffix: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: UnitNameWidget(docId: data['unit']),
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

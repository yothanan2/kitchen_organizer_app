// lib/staff_inventory_count_screen.dart
// V3: Corrected widget data access to align with the InventoryItem model.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'providers.dart';
import 'models/models.dart';
import 'add_inventory_item_screen.dart';

// A helper widget for displaying unit names efficiently.
class UnitNameWidget extends ConsumerWidget {
  final DocumentReference? unitRef;
  const UnitNameWidget({super.key, this.unitRef});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (unitRef == null) {
      return const Text('', style: TextStyle(fontStyle: FontStyle.italic));
    }
    final unitsMapAsync = ref.watch(unitsMapProvider);
    return unitsMapAsync.when(
      data: (unitsMap) => Text(unitsMap[unitRef!.id] ?? 'N/A'),
      loading: () => const Text('...'),
      error: (_, __) => const Text('?'),
    );
  }
}

// A helper widget for displaying supplier names efficiently.
class SupplierNameWidget extends ConsumerWidget {
  final DocumentReference? supplierRef;
  const SupplierNameWidget({super.key, this.supplierRef});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (supplierRef == null) {
      return const SizedBox.shrink();
    }
    final suppliersMapAsync = ref.watch(suppliersMapProvider);
    return suppliersMapAsync.when(
      data: (suppliersMap) => Text(
        'Supplier: ${suppliersMap[supplierRef!.id] ?? 'Unknown'}',
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
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, num> _originalQuantities = {};
  final Set<String> _dirtyItems = {};

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _updateQuantity(String docId, num originalQuantity) {
    final controller = _controllers[docId];
    if (controller == null) return;

    final newQuantity = num.tryParse(controller.text);
    if (newQuantity != null && newQuantity != originalQuantity) {
      FirebaseFirestore.instance
          .collection('inventoryItems')
          .doc(docId)
          .update({'quantityOnHand': newQuantity, 'lastUpdated': FieldValue.serverTimestamp()})
          .then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quantity updated!'), backgroundColor: Colors.green),
        );
        setState(() {
          _dirtyItems.remove(docId);
          _originalQuantities[docId] = newQuantity;
        });
        _focusNodes[docId]?.unfocus();
      })
          .catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $error'), backgroundColor: Colors.red),
        );
      });
    }
  }

  void _setupController(InventoryItem item) {
    if (!_controllers.containsKey(item.id)) {
      final controller = TextEditingController(text: item.quantityOnHand.toString());
      final focusNode = FocusNode();
      _controllers[item.id] = controller;
      _focusNodes[item.id] = focusNode;
      _originalQuantities[item.id] = item.quantityOnHand;

      controller.addListener(() {
        final currentQuantity = num.tryParse(controller.text);
        if (currentQuantity != _originalQuantities[item.id]) {
          if (!_dirtyItems.contains(item.id)) {
            setState(() {
              _dirtyItems.add(item.id);
            });
          }
        } else {
          if (_dirtyItems.contains(item.id)) {
            setState(() {
              _dirtyItems.remove(item.id);
            });
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryGroupsAsync = ref.watch(inventoryGroupsProvider);

    return inventoryGroupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (groups) {
        final sortedKeys = groups.keys.toList()..sort();
        if (sortedKeys.isEmpty) {
          return const Center(child: Text("No inventory items found."));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: sortedKeys.length,
          itemBuilder: (context, index) {
            final locationName = sortedKeys[index];
            final items = groups[locationName]!;
            final inventoryItems = items.map((doc) => InventoryItem.fromFirestore(doc.data()! as Map<String, dynamic>, doc.id)).toList();

            return ExpansionTile(
              key: PageStorageKey(locationName),
              initiallyExpanded: true,
              title: Text(locationName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              children: inventoryItems.map((item) {
                _setupController(item);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(item.itemName),
                    // CORRECTED: 'unitId' is now 'unit' which is a DocumentReference.
                    subtitle: SupplierNameWidget(supplierRef: item.supplier),
                    trailing: SizedBox(
                      width: 150,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controllers[item.id],
                              focusNode: _focusNodes[item.id],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onSubmitted: (_) => _updateQuantity(item.id, _originalQuantities[item.id]!),
                            ),
                          ),
                          if (_dirtyItems.contains(item.id))
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              onPressed: () => _updateQuantity(item.id, _originalQuantities[item.id]!),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.grey),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    // CORRECTED: 'docId' is now 'documentId' in the target screen.
                                    builder: (context) => AddInventoryItemScreen(documentId: item.id),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
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
                // CORRECTED: This now passes the DocumentReference correctly.
                SupplierNameWidget(supplierRef: data['supplier'] as DocumentReference?),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: TextFormField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              decoration: InputDecoration(
                suffix: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  // CORRECTED: This now passes the DocumentReference correctly.
                  child: UnitNameWidget(unitRef: data['unit'] as DocumentReference?),
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
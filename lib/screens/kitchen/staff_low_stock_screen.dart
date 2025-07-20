import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchen_organizer_app/models/models.dart';
import 'package:kitchen_organizer_app/providers.dart';
import 'package:kitchen_organizer_app/widgets/firestore_name_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart'; // Import for groupBy

class StaffLowStockScreen extends ConsumerStatefulWidget {
  const StaffLowStockScreen({super.key});

  @override
  ConsumerState<StaffLowStockScreen> createState() => _StaffLowStockScreenState();
}

class _StaffLowStockScreenState extends ConsumerState<StaffLowStockScreen> {
  final Map<String, TextEditingController> _orderQuantityControllers = {};
  String _searchTerm = '';

  @override
  void dispose() {
    for (final controller in _orderQuantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submitOrderRequest() async {
    // This function's logic remains the same.
    final currentUser = ref.read(appUserProvider).value;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Could not identify user.")),
      );
      return;
    }

    final itemsToOrder = <Map<String, dynamic>>[];
    _orderQuantityControllers.forEach((itemId, controller) {
      final quantityText = controller.text.trim();
      if (quantityText.isNotEmpty) {
        final double? quantity = double.tryParse(quantityText);
        final item = ref.read(lowStockItemsProvider).value?.firstWhere((i) => i.id == itemId);
        if (quantity != null && quantity > 0 && item != null) {
          itemsToOrder.add({
            'inventoryItemRef': FirebaseFirestore.instance.collection('inventoryItems').doc(item.id),
            'itemName': item.itemName,
            'quantity': quantity,
            'unit': item.unit?.id,
          });
        }
      }
    });

    if (itemsToOrder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a quantity for at least one item.")),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('orderRequests').add({
        'requestedBy': currentUser.fullName,
        'requesterId': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'items': itemsToOrder,
      });

      for (final controller in _orderQuantityControllers.values) {
        controller.clear();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Order request successfully submitted!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to submit order request: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowStockItemsAsync = ref.watch(lowStockItemsProvider);
    final suppliersAsync = ref.watch(suppliersMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Low Stock Items'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchTerm = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: lowStockItemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No items are currently low on stock. Great job!'),
              ),
            );
          }

          final filteredItems = items.where((item) {
            return item.itemName.toLowerCase().contains(_searchTerm);
          }).toList();

          // Group by supplier
          final groupedBySupplier = groupBy<InventoryItem, String>(
            filteredItems,
                (item) => item.supplier?.id ?? 'unassigned',
          );

          return suppliersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error loading suppliers: $err')),
            data: (suppliersMap) {
              final sortedSupplierIds = groupedBySupplier.keys.toList()
                ..sort((a, b) {
                  final nameA = suppliersMap[a] ?? 'Unassigned';
                  final nameB = suppliersMap[b] ?? 'Unassigned';
                  return nameA.compareTo(nameB);
                });

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: sortedSupplierIds.length,
                      itemBuilder: (context, index) {
                        final supplierId = sortedSupplierIds[index];
                        final supplierItems = groupedBySupplier[supplierId]!;
                        final supplierName = suppliersMap[supplierId] ?? 'Unassigned Supplier';

                        // Ensure controllers exist for all visible items
                        for (final item in supplierItems) {
                          if (!_orderQuantityControllers.containsKey(item.id)) {
                            _orderQuantityControllers[item.id] = TextEditingController();
                          }
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ExpansionTile(
                            title: Text(supplierName, style: Theme.of(context).textTheme.titleLarge),
                            initiallyExpanded: true,
                            children: supplierItems.map((item) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.itemName,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.red.shade900),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Min Stock: ${item.minStockLevel}'),
                                            Text(
                                              'Current: ${item.quantityOnHand}',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            const Text('Order: '),
                                            SizedBox(
                                              width: 80,
                                              child: TextField(
                                                controller: _orderQuantityControllers[item.id],
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                textAlign: TextAlign.center,
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            FirestoreNameWidget(
                                              docRef: item.unit,
                                              builder: (context, unitName) => Text(unitName),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 16),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: _submitOrderRequest,
                      icon: const Icon(Icons.playlist_add_check_rounded),
                      label: const Text('Submit Order Request'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
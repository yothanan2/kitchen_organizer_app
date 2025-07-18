// lib/staff_low_stock_screen.dart
// NEW SCREEN: A dedicated view for staff to see low-stock items and request re-orders.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchen_organizer_app/providers.dart';
import 'package:kitchen_organizer_app/widgets/firestore_name_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StaffLowStockScreen extends ConsumerStatefulWidget {
  const StaffLowStockScreen({super.key});

  @override
  ConsumerState<StaffLowStockScreen> createState() => _StaffLowStockScreenState();
}

class _StaffLowStockScreenState extends ConsumerState<StaffLowStockScreen> {
  // Use a map to hold the controllers for each item's order quantity
  final Map<String, TextEditingController> _orderQuantityControllers = {};

  @override
  void dispose() {
    for (final controller in _orderQuantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submitOrderRequest() async {
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
        'status': 'pending', // e.g., pending, ordered, received
        'items': itemsToOrder,
      });

      // Clear controllers and show success message
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Low Stock Items'),
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

          // Ensure controllers exist for all visible items
          for (final item in items) {
            if (!_orderQuantityControllers.containsKey(item.id)) {
              _orderQuantityControllers[item.id] = TextEditingController();
            }
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.itemName,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.red.shade900),
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
                                      docRef: item.unit != null ? FirebaseFirestore.instance.collection('units').doc(item.unit!.id) : null,
                                      builder: (context, unitName) => Text(unitName),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
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
      ),
    );
  }
}
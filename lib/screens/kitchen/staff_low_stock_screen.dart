// lib/staff_low_stock_screen.dart
// NEW SCREEN: A dedicated view for staff to see low-stock items and request re-orders.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchen_organizer_app/providers.dart';
import 'package:kitchen_organizer_app/models/models.dart';
import 'package:kitchen_organizer_app/widgets/firestore_name_widget.dart';

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

  void _submitOrderRequest() {
    // In the future, this button will send the requested items to a new
    // "Items to Order" page or create a task for the admin.
    // For now, it will just show a confirmation.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Order request submitted! (Functionality to be built)"),
        backgroundColor: Colors.green,
      ),
    );
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
                                    FirestoreNameWidget(collection: 'units', docId: item.unit?.id),
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
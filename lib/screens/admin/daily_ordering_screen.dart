import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchen_organizer_app/controllers/daily_ordering_controller.dart';
import 'package:kitchen_organizer_app/widgets/firestore_name_widget.dart';

class DailyOrderingScreen extends ConsumerWidget {
  const DailyOrderingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyOrderingControllerProvider);
    final controller = ref.read(dailyOrderingControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Ordering Suggestions'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.suggestionsBySupplier.isEmpty
              ? const Center(
                  child: Text(
                    'No pending order suggestions.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(8),
                  children: state.suggestionsBySupplier.entries.map((entry) {
                    final supplierName = entry.key;
                    final items = entry.value;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 4,
                      child: ExpansionTile(
                        title: Text(
                          supplierName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        initiallyExpanded: true,
                        children: [
                          ...items.map((item) => _buildSuggestionTile(context, item, controller)),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () { /* TODO: Add item */ },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Item'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final error = await controller.finalizeOrder(supplierName);
                                    if (!context.mounted) return;
                                    if (error != null) {
                                      ScaffoldMessenger.of((context)).showSnackBar(
                                        SnackBar(content: Text(error), backgroundColor: Colors.red),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Order finalized successfully!'), backgroundColor: Colors.green),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.send),
                                  label: const Text('Finalize & Place Order'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  Widget _buildSuggestionTile(BuildContext context, OrderSuggestionItem item, DailyOrderingController controller) {
    final quantityController = TextEditingController(text: item.quantityToOrder.toString());

    return ListTile(
      title: Text(item.itemName),
      subtitle: FirestoreNameWidget(
        docRef: item.unitRef,
        builder: (context, unitName) => Text('Unit: $unitName'),
      ),
      trailing: SizedBox(
        width: 150,
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Qty',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final newQuantity = num.tryParse(value);
                  if (newQuantity != null) {
                    controller.updateQuantity(item.id, newQuantity);
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => controller.removeItem(item.id),
            ),
          ],
        ),
      ),
    );
  }
}

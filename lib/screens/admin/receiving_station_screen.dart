import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchen_organizer_app/controllers/receiving_station_controller.dart';
import 'package:kitchen_organizer_app/screens/admin/receiving_history_screen.dart';
import 'package:kitchen_organizer_app/widgets/firestore_name_widget.dart';

class ReceivingStationScreen extends ConsumerWidget {
  const ReceivingStationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(receivingStationControllerProvider);
    final controller = ref.read(receivingStationControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receiving Station'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ReceivingHistoryScreen())),
            tooltip: 'Receiving History',
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.itemsBySupplierAndDate.isEmpty
              ? const Center(
                  child: Text(
                    'No incoming orders.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(8),
                  children: state.itemsBySupplierAndDate.entries.map((entry) {
                    final groupKey = entry.key;
                    final items = entry.value;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 4,
                      child: ExpansionTile(
                        title: Text(
                          groupKey, // "Supplier Name - YYYY-MM-DD"
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        initiallyExpanded: true,
                        children: [
                          ...items.map((item) => _buildReceivingTile(context, item)),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final error = await controller.acceptDelivery(groupKey);
                                if (!context.mounted) return;
                                if (error != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error), backgroundColor: Colors.red),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Delivery accepted and inventory updated!'), backgroundColor: Colors.green),
                                  );
                                }
                              },
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Accept Delivery'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          )
                        ],
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  Widget _buildReceivingTile(BuildContext context, ReceivingItem item) {
    return ListTile(
      title: Text(item.itemName),
      subtitle: FirestoreNameWidget(
        docRef: item.unitRef,
        builder: (context, unitName) => Text('Ordered: ${item.orderedQuantity} $unitName'),
      ),
      trailing: SizedBox(
        width: 120,
        child: TextFormField(
          controller: item.receivedQuantityController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Received',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}

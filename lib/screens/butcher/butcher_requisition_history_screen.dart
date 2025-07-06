
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers.dart';
import 'package:kitchen_organizer_app/screens/butcher/butcher_requisition_screen.dart';

class ButcherRequisitionHistoryScreen extends ConsumerWidget {
  const ButcherRequisitionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(requisitionHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Requisition History'),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (requisitions) {
          if (requisitions.isEmpty) {
            return const Center(
              child: Text(
                'No past requisitions found.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: requisitions.length,
            itemBuilder: (context, index) {
              final requisition = requisitions[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ExpansionTile(
                  title: Text(
                    'Requisition from ${DateFormat.yMMMd().format(requisition.createdAt)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Status: ${requisition.status}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.replay),
                    tooltip: 'Re-order',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ButcherRequisitionScreen(
                            reorderItems: requisition.items,
                          ),
                        ),
                      );
                    },
                  ),
                  children: requisition.items.map((item) {
                    return ListTile(
                      title: Text(item.itemName),
                      trailing: Text('${item.quantity} ${item.unit}'),
                    );
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

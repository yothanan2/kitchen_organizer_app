// lib/screens/butcher/butcher_requisition_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers.dart';

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
                'No completed requisitions found.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }
          return ListView.builder(
            itemCount: requisitions.length,
            itemBuilder: (context, index) {
              final requisition = requisitions[index];
              final formattedDate =
              DateFormat('MMM d, yyyy - hh:mm a').format(requisition.createdAt);
              final itemCount = requisition.items.length;

              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('Requisition - $formattedDate'),
                  subtitle: Text(
                      '$itemCount item(s) - Requested by ${requisition.requestedBy}'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Requisition Details'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: requisition.items.map((item) {
                            // --- THIS IS THE FIX ---
                            return Text(
                                '- ${item.itemName} (${item.quantity} ${item.unit})');
                            // --- END OF FIX ---
                          }).toList(),
                        ),
                        actions: [
                          TextButton(
                            child: const Text('Close'),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
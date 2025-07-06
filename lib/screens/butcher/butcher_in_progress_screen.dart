
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers.dart';

class ButcherInProgressScreen extends ConsumerWidget {
  const ButcherInProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openRequisitionsAsync = ref.watch(openRequisitionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('In-Progress Requisitions'),
      ),
      body: openRequisitionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (requisitions) {
          if (requisitions.isEmpty) {
            return const Center(
              child: Text(
                'No open requisitions.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: requisitions.length,
            itemBuilder: (context, index) {
              final requisition = requisitions[index];
              final data = requisition.data() as Map<String, dynamic>;
              final items = (data['items'] as List<dynamic>)
                  .map((item) => item as Map<String, dynamic>)
                  .toList();

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ExpansionTile(
                  title: Text(
                    'Requisition from ${DateFormat.yMMMd().format((data['createdAt'] as Timestamp).toDate())}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Status: ${data['status']}'),
                  children: items.map((item) {
                    return ListTile(
                      title: Text(item['itemName'] ?? 'N/A'),
                      trailing: Text('${item['quantity']} ${item['unit']}'),
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

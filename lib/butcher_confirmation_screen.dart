// lib/butcher_confirmation_screen.dart
// This new screen allows the butcher to confirm they have received prepared items.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'providers.dart';

class ButcherConfirmationScreen extends ConsumerWidget {
  const ButcherConfirmationScreen({super.key});

  Future<void> _confirmReceipt(DocumentReference docRef) async {
    // This marks the requisition as 'received', the final step.
    await docRef.update({'status': 'received'});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preparedRequisitionsAsync = ref.watch(preparedRequisitionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Received Items'),
      ),
      body: preparedRequisitionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (requisitions) {
          if (requisitions.isEmpty) {
            return const Center(
              child: Text(
                'No items are currently waiting for pickup.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            itemCount: requisitions.length,
            itemBuilder: (context, index) {
              final doc = requisitions[index];
              final data = doc.data() as Map<String, dynamic>;
              final forDate = (data['requisitionForDate'] as Timestamp).toDate();
              final items = List<Map<String, dynamic>>.from(data['items']);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.amber.shade100,
                child: ListTile(
                  title: Text(
                    'Order for ${DateFormat('EEE, MMM d').format(forDate)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${items.length} items prepared. Tap to confirm receipt.',
                    style: const TextStyle(color: Colors.black87),
                  ),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                  onTap: () => _confirmReceipt(doc.reference),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
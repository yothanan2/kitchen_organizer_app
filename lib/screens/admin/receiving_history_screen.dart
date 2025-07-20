import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchen_organizer_app/providers.dart';
import 'package:kitchen_organizer_app/widgets/firestore_name_widget.dart';
import 'package:collection/collection.dart';

class ReceivingHistoryScreen extends ConsumerWidget {
  const ReceivingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receivedAsync = ref.watch(receivedSuggestionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receiving History'),
      ),
      body: receivedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (snapshot) {
          if (snapshot.docs.isEmpty) {
            return const Center(
              child: Text(
                'No received orders found.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          // Group by the order date (the ID of the parent document)
          final groupedByDate = groupBy<QueryDocumentSnapshot, String>(
            snapshot.docs,
            (doc) => doc.reference.parent.parent!.id,
          );

          return ListView.builder(
            itemCount: groupedByDate.length,
            itemBuilder: (context, index) {
              final date = groupedByDate.keys.elementAt(index);
              final items = groupedByDate[date]!;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ExpansionTile(
                  title: Text(
                    'Order from: $date',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  initiallyExpanded: true,
                  children: items.map((itemDoc) {
                    final data = itemDoc.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['itemName'] ?? 'Unknown Item'),
                      subtitle: FirestoreNameWidget(
                        docRef: data['unitRef'] as DocumentReference?,
                        builder: (context, unitName) {
                          return Text('Ordered: ${data['quantityToOrder']} $unitName');
                        },
                      ),
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

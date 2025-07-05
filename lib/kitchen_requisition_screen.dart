// lib/kitchen_requisition_screen.dart
// This screen displays grouped requisitions for the kitchen staff to prepare.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'providers.dart';

class KitchenRequisitionScreen extends ConsumerWidget {
  const KitchenRequisitionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openRequisitionsAsync = ref.watch(openRequisitionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Requisitions'),
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
            itemCount: requisitions.length,
            itemBuilder: (context, index) {
              final requisitionDoc = requisitions[index];
              return RequisitionCard(requisitionDoc: requisitionDoc);
            },
          );
        },
      ),
    );
  }
}

class RequisitionCard extends ConsumerStatefulWidget {
  final DocumentSnapshot requisitionDoc;
  const RequisitionCard({super.key, required this.requisitionDoc});

  @override
  ConsumerState<RequisitionCard> createState() => _RequisitionCardState();
}

class _RequisitionCardState extends ConsumerState<RequisitionCard> {

  Future<void> _toggleItemPrepared(int itemIndex, bool isPrepared) async {
    final docRef = widget.requisitionDoc.reference;
    final List<dynamic> items = List.from((widget.requisitionDoc.data() as Map<String, dynamic>)['items']);

    // Update the specific item's prepared status
    items[itemIndex]['isPrepared'] = isPrepared;

    // Check if all items are now prepared
    final allItemsPrepared = items.every((item) => item['isPrepared'] == true);

    // Update the requisition document
    await docRef.update({
      'items': items,
      'status': allItemsPrepared ? 'prepared' : 'requested',
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.requisitionDoc.data() as Map<String, dynamic>;
    final createdBy = data['createdBy'] ?? 'Unknown';
    final forDate = (data['requisitionForDate'] as Timestamp).toDate();
    final status = data['status'] ?? 'unknown';
    final items = List<Map<String, dynamic>>.from(data['items']);

    final statusColor = status == 'requested' ? Colors.red.shade100 : Colors.amber.shade100;
    final statusIcon = status == 'requested' ? Icons.new_releases : Icons.check_circle_outline;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: statusColor,
      elevation: 4,
      child: ExpansionTile(
        leading: Icon(statusIcon, color: Theme.of(context).primaryColor),
        title: Text(
          'Request from $createdBy for ${DateFormat('EEE, MMM d').format(forDate)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Status: $status'),
        children: [
          for (int i = 0; i < items.length; i++)
            _buildItemTile(items[i], i),
        ],
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item, int index) {
    final itemName = item['itemName'] ?? 'Unnamed Item';
    final quantity = item['quantity'] ?? 0;
    final unitRef = item['unitRef'] as DocumentReference?;
    final isPrepared = item['isPrepared'] ?? false;

    return Container(
      color: Colors.white.withOpacity(0.7),
      child: ListTile(
        title: Text(itemName),
        subtitle: unitRef != null
            ? FirestoreNameWidget(
          docRef: unitRef,
          builder: (context, unitName) => Text('$quantity $unitName'),
        )
            : Text('$quantity'),
        trailing: Checkbox(
          value: isPrepared,
          onChanged: (value) => _toggleItemPrepared(index, value ?? false),
          activeColor: Colors.green,
        ),
      ),
    );
  }
}

// Helper widget to resolve DocumentReference names efficiently.
class FirestoreNameWidget extends ConsumerWidget {
  final DocumentReference docRef;
  final Widget Function(BuildContext, String) builder;

  const FirestoreNameWidget({
    super.key,
    required this.docRef,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncName = ref.watch(docNameProvider(docRef));
    return asyncName.when(
      loading: () => builder(context, '...'),
      error: (err, stack) => builder(context, 'Error'),
      data: (name) => builder(context, name),
    );
  }
}

// Provider to get the name from any document reference.
final docNameProvider = FutureProvider.autoDispose.family<String, DocumentReference>((ref, docRef) async {
  final doc = await docRef.get();
  if (doc.exists) {
    return (doc.data() as Map<String, dynamic>)['name'] ?? 'Unnamed';
  }
  return 'Unknown';
});


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Helper widget to resolve DocumentReference names efficiently.
class FirestoreNameWidget extends ConsumerWidget {
  final DocumentReference<Object?>? docRef;
  final Widget Function(BuildContext, String) builder;

  const FirestoreNameWidget({
    super.key,
    this.docRef,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (docRef == null) {
      return builder(context, 'N/A'); // Or some default text for null docRef
    }
    final asyncName = ref.watch(docNameProvider(docRef!));
    return asyncName.when(
      loading: () => builder(context, '...'),
      error: (err, stack) => builder(context, 'Error'),
      data: (name) => builder(context, name),
    );
  }
}

// Provider to get the name from any document reference.
final docNameProvider = FutureProvider.autoDispose.family<String, DocumentReference<Object?>?>((ref, docRef) async {
  if (docRef == null) return 'N/A';
  final doc = await docRef.get();
  if (doc.exists) {
    return (doc.data() as Map<String, dynamic>)['name'] ?? 'Unnamed';
  }
  return 'Unknown';
});
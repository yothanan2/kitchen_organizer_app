import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

// Data class for a single item being received
@immutable
class ReceivingItem {
  final String suggestionId;
  final String orderDate;
  final DocumentReference inventoryItemRef;
  final String itemName;
  final DocumentReference supplierRef;
  final String supplierName;
  final DocumentReference? unitRef;
  final num orderedQuantity;
  final TextEditingController receivedQuantityController;

  ReceivingItem({
    required this.suggestionId,
    required this.orderDate,
    required this.inventoryItemRef,
    required this.itemName,
    required this.supplierRef,
    required this.supplierName,
    this.unitRef,
    required this.orderedQuantity,
  }) : receivedQuantityController = TextEditingController(text: orderedQuantity.toString());
}

// State for the screen
@immutable
class ReceivingStationState {
  final bool isLoading;
  final Map<String, List<ReceivingItem>> itemsBySupplierAndDate;

  const ReceivingStationState({
    this.isLoading = true,
    this.itemsBySupplierAndDate = const {},
  });

  ReceivingStationState copyWith({
    bool? isLoading,
    Map<String, List<ReceivingItem>>? itemsBySupplierAndDate,
  }) {
    return ReceivingStationState(
      isLoading: isLoading ?? this.isLoading,
      itemsBySupplierAndDate: itemsBySupplierAndDate ?? this.itemsBySupplierAndDate,
    );
  }
}

// Provider for the controller
final receivingStationControllerProvider = StateNotifierProvider.autoDispose<ReceivingStationController, ReceivingStationState>((ref) {
  return ReceivingStationController();
});

// The Controller
class ReceivingStationController extends StateNotifier<ReceivingStationState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ReceivingStationController() : super(const ReceivingStationState()) {
    _fetchOrderedItems();
  }

  Future<void> _fetchOrderedItems() async {
    state = state.copyWith(isLoading: true);
    try {
      final snapshot = await _firestore
          .collectionGroup('suggestions')
          .where('status', isEqualTo: 'ordered')
          .get();

      if (snapshot.docs.isEmpty) {
        state = state.copyWith(isLoading: false, itemsBySupplierAndDate: {});
        return;
      }

      // Fetch all supplier names for efficiency
      final supplierIds = snapshot.docs.map((doc) => (doc.data()['supplierRef'] as DocumentReference).id).toSet();
      final suppliersSnapshot = await _firestore.collection('suppliers').where(FieldPath.documentId, whereIn: supplierIds.toList()).get();
      final supplierNameMap = {for (var doc in suppliersSnapshot.docs) doc.id: doc.data()['name'] as String? ?? 'Unknown Supplier'};

      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        final supplierId = (data['supplierRef'] as DocumentReference).id;
        final orderDate = doc.reference.parent.parent!.id; // The ID of the dailyOrderingSuggestions doc
        return ReceivingItem(
          suggestionId: doc.id,
          orderDate: orderDate,
          inventoryItemRef: data['inventoryItemRef'],
          itemName: data['itemName'],
          supplierRef: data['supplierRef'],
          supplierName: supplierNameMap[supplierId]!,
          unitRef: data['unitRef'],
          orderedQuantity: data['quantityToOrder'],
        );
      }).toList();

      // Group by a composite key of supplier and date
      final grouped = groupBy<ReceivingItem, String>(items, (item) => '${item.supplierName} - ${item.orderDate}');
      
      state = state.copyWith(isLoading: false, itemsBySupplierAndDate: grouped);

    } catch (e) {
      debugPrint("Error fetching ordered items: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  Future<String?> acceptDelivery(String groupKey) async {
    final itemsToReceive = state.itemsBySupplierAndDate[groupKey];
    if (itemsToReceive == null || itemsToReceive.isEmpty) {
      return "No items to receive for this delivery.";
    }

    final batch = _firestore.batch();

    try {
      for (final item in itemsToReceive) {
        final receivedQuantity = num.tryParse(item.receivedQuantityController.text);
        if (receivedQuantity == null) {
          throw Exception("Invalid quantity for ${item.itemName}.");
        }

        // 1. Update the inventory item's quantity
        final inventoryDoc = await item.inventoryItemRef.get();
        if (inventoryDoc.exists) {
          final currentQuantity = (inventoryDoc.data() as Map<String, dynamic>)['quantityOnHand'] ?? 0;
          final newQuantity = currentQuantity + receivedQuantity;
          batch.update(item.inventoryItemRef, {'quantityOnHand': newQuantity});
        }

        // 2. Update the suggestion's status to 'received'
        final suggestionRef = _firestore
            .collection('dailyOrderingSuggestions')
            .doc(item.orderDate)
            .collection('suggestions')
            .doc(item.suggestionId);
        batch.update(suggestionRef, {'status': 'received'});
      }

      await batch.commit();

      // Remove the accepted group from the UI
      final newMap = Map<String, List<ReceivingItem>>.from(state.itemsBySupplierAndDate)..remove(groupKey);
      state = state.copyWith(itemsBySupplierAndDate: newMap);

      return null; // Success
    } catch (e) {
      return "Failed to accept delivery: ${e.toString()}";
    }
  }

  @override
  void dispose() {
    for (final group in state.itemsBySupplierAndDate.values) {
      for (final item in group) {
        item.receivedQuantityController.dispose();
      }
    }
    super.dispose();
  }
}

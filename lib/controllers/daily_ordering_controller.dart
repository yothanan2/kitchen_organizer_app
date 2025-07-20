import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

// Data class for a single suggestion item
@immutable
class OrderSuggestionItem {
  final String id;
  final DocumentReference inventoryItemRef;
  final String itemName;
  final DocumentReference supplierRef;
  final String supplierName; // Denormalized for easy grouping
  final DocumentReference? unitRef;
  final num quantityToOrder;
  final String status;

  const OrderSuggestionItem({
    required this.id,
    required this.inventoryItemRef,
    required this.itemName,
    required this.supplierRef,
    required this.supplierName,
    this.unitRef,
    required this.quantityToOrder,
    required this.status,
  });
}

// State for the screen
@immutable
class DailyOrderingState {
  final bool isLoading;
  final Map<String, List<OrderSuggestionItem>> suggestionsBySupplier;

  const DailyOrderingState({
    this.isLoading = true,
    this.suggestionsBySupplier = const {},
  });

  DailyOrderingState copyWith({
    bool? isLoading,
    Map<String, List<OrderSuggestionItem>>? suggestionsBySupplier,
  }) {
    return DailyOrderingState(
      isLoading: isLoading ?? this.isLoading,
      suggestionsBySupplier: suggestionsBySupplier ?? this.suggestionsBySupplier,
    );
  }
}

// Provider for the controller
final dailyOrderingControllerProvider = StateNotifierProvider.autoDispose<DailyOrderingController, DailyOrderingState>((ref) {
  return DailyOrderingController(ref);
});

// The Controller
class DailyOrderingController extends StateNotifier<DailyOrderingState> {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DailyOrderingController(this._ref) : super(const DailyOrderingState()) {
    _fetchSuggestions();
  }

  Future<void> _fetchSuggestions() async {
    state = state.copyWith(isLoading: true);
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final snapshot = await _firestore
          .collection('dailyOrderingSuggestions')
          .doc(today)
          .collection('suggestions')
          .where('status', isEqualTo: 'pending')
          .get();

      if (snapshot.docs.isEmpty) {
        state = state.copyWith(isLoading: false, suggestionsBySupplier: {});
        return;
      }

      // Fetch all supplier names in one go for efficiency
      final supplierIds = snapshot.docs.map((doc) => (doc.data()['supplierRef'] as DocumentReference).id).toSet();
      final suppliersSnapshot = await _firestore.collection('suppliers').where(FieldPath.documentId, whereIn: supplierIds.toList()).get();
      final supplierNameMap = {for (var doc in suppliersSnapshot.docs) doc.id: doc.data()['name'] as String? ?? 'Unknown Supplier'};

      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        final supplierId = (data['supplierRef'] as DocumentReference).id;
        return OrderSuggestionItem(
          id: doc.id,
          inventoryItemRef: data['inventoryItemRef'],
          itemName: data['itemName'],
          supplierRef: data['supplierRef'],
          supplierName: supplierNameMap[supplierId]!,
          unitRef: data['unitRef'],
          quantityToOrder: data['quantityToOrder'],
          status: data['status'],
        );
      }).toList();

      // Group by supplier name
      final grouped = groupBy<OrderSuggestionItem, String>(items, (item) => item.supplierName);
      
      state = state.copyWith(isLoading: false, suggestionsBySupplier: grouped);

    } catch (e) {
      debugPrint("Error fetching suggestions: $e");
      state = state.copyWith(isLoading: false);
    }
  }
  
  void updateQuantity(String itemId, num newQuantity) {
    final newMap = Map<String, List<OrderSuggestionItem>>.from(state.suggestionsBySupplier);
    for (final supplier in newMap.keys) {
      final index = newMap[supplier]!.indexWhere((item) => item.id == itemId);
      if (index != -1) {
        final oldItem = newMap[supplier]![index];
        final newItem = OrderSuggestionItem(
          id: oldItem.id,
          inventoryItemRef: oldItem.inventoryItemRef,
          itemName: oldItem.itemName,
          supplierRef: oldItem.supplierRef,
          supplierName: oldItem.supplierName,
          unitRef: oldItem.unitRef,
          quantityToOrder: newQuantity,
          status: oldItem.status,
        );
        newMap[supplier]![index] = newItem;
        state = state.copyWith(suggestionsBySupplier: newMap);
        return;
      }
    }
  }

  void removeItem(String itemId) {
    final newMap = Map<String, List<OrderSuggestionItem>>.from(state.suggestionsBySupplier);
    for (final supplier in newMap.keys) {
      newMap[supplier]!.removeWhere((item) => item.id == itemId);
      if (newMap[supplier]!.isEmpty) {
        newMap.remove(supplier);
      }
    }
    state = state.copyWith(suggestionsBySupplier: newMap);
  }

  Future<String?> finalizeOrder(String supplierName) async {
    final itemsToFinalize = state.suggestionsBySupplier[supplierName];
    if (itemsToFinalize == null || itemsToFinalize.isEmpty) {
      return "No items to order for this supplier.";
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final suggestionsCollection = _firestore.collection('dailyOrderingSuggestions').doc(today).collection('suggestions');
    final batch = _firestore.batch();

    try {
      for (final item in itemsToFinalize) {
        final docRef = suggestionsCollection.doc(item.id);
        batch.update(docRef, {
          'quantityToOrder': item.quantityToOrder,
          'status': 'ordered',
        });
      }
      await batch.commit();
      
      // Remove the finalized group from the UI
      final newMap = Map<String, List<OrderSuggestionItem>>.from(state.suggestionsBySupplier)..remove(supplierName);
      state = state.copyWith(suggestionsBySupplier: newMap);
      
      return null; // Success
    } catch (e) {
      return "Failed to finalize order: ${e.toString()}";
    }
  }
}

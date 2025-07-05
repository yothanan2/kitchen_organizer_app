// lib/models/models.dart
// V7: Made Requisition model backwards-compatible to handle old data.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint

// Helper function to safely convert a dynamic value to a DocumentReference
DocumentReference? _toDocRef(dynamic value) {
  if (value is DocumentReference) {
    return value;
  }
  return null;
}

// --- REQUISITION MODELS ---

class RequisitionItem {
  final String itemName;
  final num quantity;
  final String unit;

  RequisitionItem({
    required this.itemName,
    required this.quantity,
    required this.unit,
  });

  factory RequisitionItem.fromMap(Map<String, dynamic> map) {
    return RequisitionItem(
      itemName: map['itemName'] ?? 'Unknown Item',
      quantity: map['quantity'] ?? 0,
      // Reads the 'unit' string field. Fallbacks to empty if not found.
      unit: map['unit'] as String? ?? '',
    );
  }
}

class Requisition {
  final String id;
  final String status;
  final DateTime createdAt;
  final String requestedBy;
  final List<RequisitionItem> items;

  Requisition({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.requestedBy,
    required this.items,
  });

  // --- THIS IS THE FIX ---
  factory Requisition.fromFirestore(DocumentSnapshot doc) {
    try {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      // Defensive check for the items list
      var itemsList = (data['items'] as List<dynamic>? ?? [])
          .map((item) => RequisitionItem.fromMap(item as Map<String, dynamic>))
          .toList();

      // Defensive check for timestamp
      final createdAtTimestamp = data['createdAt'] as Timestamp?;

      // Defensive check for user name
      final requestedByName = data['createdBy'] as String?;

      return Requisition(
        id: doc.id,
        status: data['status'] ?? 'unknown',
        // Use a default old date if timestamp is null
        createdAt: createdAtTimestamp?.toDate() ?? DateTime(1970),
        // Use a default name if user field is null
        requestedBy: requestedByName ?? 'Unknown User',
        items: itemsList,
      );
    } catch (e) {
      // If any error occurs during parsing, print it and return a placeholder.
      // This prevents the whole list from failing.
      debugPrint('Error parsing requisition ${doc.id}: $e');
      return Requisition(
        id: doc.id,
        status: 'parsing_error',
        createdAt: DateTime(1970),
        requestedBy: 'Error',
        items: [],
      );
    }
  }
// --- END OF FIX ---
}

// --- EXISTING MODELS ---

class InventoryItem {
  final String id;
  final String itemName;
  final String? itemCode;
  final DocumentReference? category;
  final DocumentReference? supplier;
  final DocumentReference? unit;
  final num parLevel;
  final num quantityOnHand;
  final num minStockLevel;
  final DateTime? lastUpdated;
  final bool isButcherItem;
  final DocumentReference? location;

  InventoryItem({
    required this.id,
    required this.itemName,
    this.itemCode,
    this.category,
    this.supplier,
    this.unit,
    required this.parLevel,
    required this.quantityOnHand,
    required this.minStockLevel,
    this.lastUpdated,
    this.isButcherItem = false,
    this.location,
  });

  factory InventoryItem.fromFirestore(Map<String, dynamic> data, String id) {
    return InventoryItem(
      id: id,
      itemName: data['itemName'] ?? '',
      itemCode: data['itemCode'],
      category: _toDocRef(data['category']),
      supplier: _toDocRef(data['supplier']),
      unit: _toDocRef(data['unit']),
      parLevel: data['parLevel'] ?? 0,
      quantityOnHand: data['quantityOnHand'] ?? 0,
      minStockLevel: data['minStockLevel'] ?? 0,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
      isButcherItem: data['isButcherItem'] ?? false,
      location: _toDocRef(data['location']),
    );
  }
}

class Dish {
  final String id;
  final String dishName;
  final String category;
  final String recipeInstructions;
  final bool isActive;
  final bool isComponent;
  final DateTime? lastUpdated;
  final List<Ingredient> ingredients;
  final List<PrepTask> prepTasks;

  Dish({
    required this.id,
    required this.dishName,
    required this.category,
    required this.recipeInstructions,
    required this.isActive,
    required this.isComponent,
    this.lastUpdated,
    this.ingredients = const [],
    this.prepTasks = const [],
  });

  Dish copyWith({
    String? id,
    String? dishName,
    String? category,
    String? recipeInstructions,
    bool? isActive,
    bool? isComponent,
    DateTime? lastUpdated,
    List<Ingredient>? ingredients,
    List<PrepTask>? prepTasks,
  }) {
    return Dish(
      id: id ?? this.id,
      dishName: dishName ?? this.dishName,
      category: category ?? this.category,
      recipeInstructions: recipeInstructions ?? this.recipeInstructions,
      isActive: isActive ?? this.isActive,
      isComponent: isComponent ?? this.isComponent,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      ingredients: ingredients ?? this.ingredients,
      prepTasks: prepTasks ?? this.prepTasks,
    );
  }

  factory Dish.fromFirestore(Map<String, dynamic> data, String id) {
    return Dish(
      id: id,
      dishName: data['dishName'] ?? 'Unnamed Dish',
      category: data['category'] ?? 'Uncategorized',
      recipeInstructions: data['recipeInstructions'] ?? '',
      isActive: data['isActive'] ?? true,
      isComponent: data['isComponent'] ?? false,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }
}

class Ingredient {
  final String id;
  final DocumentReference inventoryItemRef;
  final DocumentReference? unitId;
  final num quantity;
  final String type;

  Ingredient({
    required this.id,
    required this.inventoryItemRef,
    this.unitId,
    required this.quantity,
    required this.type,
  });

  factory Ingredient.fromFirestore(Map<String, dynamic> data, String id) {
    return Ingredient(
      id: id,
      inventoryItemRef: data['inventoryItemRef'],
      unitId: data['unitId'],
      quantity: data['quantity'] ?? 0,
      type: data['type'] ?? 'ingredient',
    );
  }
}

class PrepTask {
  final String id;
  final String taskName;
  final DocumentReference? linkedDishRef;
  final int order; // ADDED this field

  PrepTask({
    required this.id,
    required this.taskName,
    this.linkedDishRef,
    required this.order, // ADDED to constructor
  });

  // ADDED copyWith method
  PrepTask copyWith({
    String? id,
    String? taskName,
    DocumentReference? linkedDishRef,
    int? order,
  }) {
    return PrepTask(
      id: id ?? this.id,
      taskName: taskName ?? this.taskName,
      linkedDishRef: linkedDishRef ?? this.linkedDishRef,
      order: order ?? this.order,
    );
  }

  factory PrepTask.fromFirestore(Map<String, dynamic> data, String id) {
    return PrepTask(
      id: id,
      taskName: data['taskName'] ?? 'Unnamed Task',
      linkedDishRef: data['linkedDishRef'],
      order: data['order'] ?? 0, // ADDED field from Firestore
    );
  }
}
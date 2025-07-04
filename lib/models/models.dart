// lib/models/models.dart
// V3: Added 'order' field and 'copyWith' method to PrepTask model.

import 'package:cloud_firestore/cloud_firestore.dart';

// Helper function to safely convert a dynamic value to a DocumentReference
DocumentReference? _toDocRef(dynamic value) {
  if (value is DocumentReference) {
    return value;
  }
  return null;
}

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
// lib/models/models.dart
// UPDATED: Added robust copyWith methods to Dish and PrepTask models.

import 'package:cloud_firestore/cloud_firestore.dart';

abstract class BaseModel {
  final String id;
  final String name;

  const BaseModel({required this.id, required this.name});
}

class Supplier extends BaseModel {
  Supplier({required super.id, required super.name});

  factory Supplier.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Supplier(
      id: documentId,
      name: data['name'] ?? 'Unnamed Supplier',
    );
  }
}

class Category extends BaseModel {
  Category({required super.id, required super.name});

  factory Category.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Category(
      id: documentId,
      name: data['name'] ?? 'Unnamed Category',
    );
  }
}

class Location extends BaseModel {
  Location({required super.id, required super.name});

  factory Location.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Location(
      id: documentId,
      name: data['name'] ?? 'Unnamed Location',
    );
  }
}

class Unit extends BaseModel {
  Unit({required super.id, required super.name});

  factory Unit.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Unit(
      id: documentId,
      name: data['name'] ?? 'Unnamed Unit',
    );
  }
}

class InventoryItem {
  final String id;
  final String itemName;
  final bool isButcherItem;
  final num quantityOnHand;
  final num minStockLevel;
  final Timestamp? lastUpdated;
  final DocumentReference? supplier;
  final DocumentReference? category;
  final DocumentReference? location;
  final DocumentReference? unit;

  InventoryItem({
    required this.id,
    required this.itemName,
    required this.isButcherItem,
    required this.quantityOnHand,
    required this.minStockLevel,
    this.lastUpdated,
    this.supplier,
    this.category,
    this.location,
    this.unit,
  });

  factory InventoryItem.fromFirestore(
      Map<String, dynamic> data, String documentId) {
    return InventoryItem(
      id: documentId,
      itemName: data['itemName'] ?? 'Unnamed Item',
      isButcherItem: data['isButcherItem'] ?? false,
      quantityOnHand: data['quantityOnHand'] ?? 0,
      minStockLevel: data['minStockLevel'] ?? 0,
      lastUpdated: data['lastUpdated'] as Timestamp?,
      supplier: data['supplier'] as DocumentReference?,
      category: data['category'] as DocumentReference?,
      location: data['location'] as DocumentReference?,
      unit: data['unit'] as DocumentReference?,
    );
  }
}

class Ingredient {
  final String id;
  final DocumentReference inventoryItemRef;
  final DocumentReference? unitId;
  final num? quantity;
  final String type;

  Ingredient({
    required this.id,
    required this.inventoryItemRef,
    this.unitId,
    this.quantity,
    required this.type,
  });

  factory Ingredient.fromFirestore(
      Map<String, dynamic> data, String documentId) {
    return Ingredient(
      id: documentId,
      inventoryItemRef: data['inventoryItemRef'] as DocumentReference,
      unitId: data['unitId'] as DocumentReference?,
      quantity: data['quantity'] as num?,
      type: data['type'] ?? 'quantified',
    );
  }
}

class PrepTask {
  final String id;
  final String taskName;
  final DocumentReference? linkedDishRef;
  final int order;

  PrepTask({
    required this.id,
    required this.taskName,
    this.linkedDishRef,
    required this.order,
  });

  factory PrepTask.fromFirestore(Map<String, dynamic> data, String documentId) {
    return PrepTask(
      id: documentId,
      taskName: data['taskName'] ?? 'Unnamed Task',
      linkedDishRef: data['linkedDishRef'] as DocumentReference?,
      order: data['order'] ?? 0,
    );
  }

  // FIX: Added the missing copyWith method
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
}

class Dish {
  final String id;
  final String dishName;
  final String category;
  final String recipeInstructions;
  final bool isActive;
  final bool isComponent;
  final Timestamp? lastUpdated;
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

  factory Dish.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Dish(
      id: documentId,
      dishName: data['dishName'] ?? 'Unnamed Dish',
      category: data['category'] ?? '',
      recipeInstructions: data['recipeInstructions'] ?? '',
      isActive: data['isActive'] ?? true,
      isComponent: data['isComponent'] ?? false,
      lastUpdated: data['lastUpdated'] as Timestamp?,
    );
  }

  // FIX: Upgraded the copyWith method to handle all fields
  Dish copyWith({
    String? dishName,
    String? category,
    String? recipeInstructions,
    bool? isActive,
    bool? isComponent,
    List<Ingredient>? ingredients,
    List<PrepTask>? prepTasks,
  }) {
    return Dish(
      id: id,
      dishName: dishName ?? this.dishName,
      category: category ?? this.category,
      recipeInstructions: recipeInstructions ?? this.recipeInstructions,
      isActive: isActive ?? this.isActive,
      isComponent: isComponent ?? this.isComponent,
      lastUpdated: lastUpdated,
      ingredients: ingredients ?? this.ingredients,
      prepTasks: prepTasks ?? this.prepTasks,
    );
  }
}
// lib/models/models.dart
// UPDATED: Added comprehensive models for Dish, Ingredient, and PrepTask.

import 'package:cloud_firestore/cloud_firestore.dart';

// A base class to ensure all simple lookup models have an ID and a name.
abstract class BaseModel {
  final String id;
  final String name;

  const BaseModel({required this.id, required this.name});
}

// Represents a document in the 'suppliers' collection.
class Supplier extends BaseModel {
  Supplier({required super.id, required super.name});

  factory Supplier.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Supplier(
      id: documentId,
      name: data['name'] ?? 'Unnamed Supplier',
    );
  }
}

// Represents a document in the 'categories' collection.
class Category extends BaseModel {
  Category({required super.id, required super.name});

  factory Category.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Category(
      id: documentId,
      name: data['name'] ?? 'Unnamed Category',
    );
  }
}

// Represents a document in the 'locations' collection.
class Location extends BaseModel {
  Location({required super.id, required super.name});

  factory Location.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Location(
      id: documentId,
      name: data['name'] ?? 'Unnamed Location',
    );
  }
}

// Represents a document in the 'units' collection.
class Unit extends BaseModel {
  Unit({required super.id, required super.name});

  factory Unit.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Unit(
      id: documentId,
      name: data['name'] ?? 'Unnamed Unit',
    );
  }
}

// Represents a document in the 'inventoryItems' collection.
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

  factory InventoryItem.fromFirestore(Map<String, dynamic> data, String documentId) {
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

// --- NEWLY ADDED MODELS FOR DISHES ---

// Represents a single ingredient within a Dish's subcollection.
class Ingredient {
  final String id;
  final DocumentReference inventoryItemRef;
  final DocumentReference? unitId;
  final num? quantity;
  final String type; // 'quantified' or 'on-hand'

  Ingredient({
    required this.id,
    required this.inventoryItemRef,
    this.unitId,
    this.quantity,
    required this.type,
  });

  factory Ingredient.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Ingredient(
      id: documentId,
      inventoryItemRef: data['inventoryItemRef'] as DocumentReference,
      unitId: data['unitId'] as DocumentReference?,
      quantity: data['quantity'] as num?,
      type: data['type'] ?? 'quantified',
    );
  }
}

// Represents a single prep task within a Dish's subcollection.
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
}

// Represents a main Dish document.
class Dish {
  final String id;
  final String dishName;
  final String category;
  final String recipeInstructions;
  final bool isActive;
  final bool isComponent;
  final Timestamp? lastUpdated;
  // This will hold the subcollection data after we fetch it.
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

  // A helper method to create a new copy of a Dish with updated subcollections.
  Dish copyWith({
    List<Ingredient>? ingredients,
    List<PrepTask>? prepTasks,
  }) {
    return Dish(
      id: id,
      dishName: dishName,
      category: category,
      recipeInstructions: recipeInstructions,
      isActive: isActive,
      isComponent: isComponent,
      lastUpdated: lastUpdated,
      ingredients: ingredients ?? this.ingredients,
      prepTasks: prepTasks ?? this.prepTasks,
    );
  }
}
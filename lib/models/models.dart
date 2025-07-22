// lib/models/models.dart
// V8: Added toFirestore methods and IngredientType enum for controller compatibility.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint

// --- ENUMS ---
enum IngredientType { quantified, onHand }

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

  factory Requisition.fromFirestore(DocumentSnapshot doc) {
    try {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      var itemsList = (data['items'] as List<dynamic>? ?? [])
          .map((item) => RequisitionItem.fromMap(item as Map<String, dynamic>))
          .toList();
      final createdAtTimestamp = data['createdAt'] as Timestamp?;
      final requestedByName = data['createdBy'] as String?;

      return Requisition(
        id: doc.id,
        status: data['status'] ?? 'unknown',
        createdAt: createdAtTimestamp?.toDate() ?? DateTime(1970),
        requestedBy: requestedByName ?? 'Unknown User',
        items: itemsList,
      );
    } catch (e) {
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
      category: (data['category'] is String && (data['category'] as String).isNotEmpty)
          ? FirebaseFirestore.instance.collection('categories').doc(data['category'])
          : (data['category'] is DocumentReference ? data['category'] as DocumentReference? : null),
      supplier: (data['supplier'] is String && (data['supplier'] as String).isNotEmpty)
          ? FirebaseFirestore.instance.collection('suppliers').doc(data['supplier'])
          : (data['supplier'] is DocumentReference ? data['supplier'] as DocumentReference? : null),
      unit: (data['unit'] is String && (data['unit'] as String).isNotEmpty)
          ? FirebaseFirestore.instance.collection('units').doc(data['unit'])
          : (data['unit'] is DocumentReference ? data['unit'] as DocumentReference? : null),
      parLevel: data['parLevel'] ?? 0,
      quantityOnHand: data['quantityOnHand'] ?? 0,
      minStockLevel: data['minStockLevel'] ?? 0,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
      isButcherItem: data['isButcherItem'] ?? false,
      location: (data['location'] is String && (data['location'] as String).isNotEmpty)
          ? FirebaseFirestore.instance.collection('locations').doc(data['location'])
          : (data['location'] is DocumentReference ? data['location'] as DocumentReference? : null),
    );
  }
}

class Dish {
  final String id;
  final String dishName;
  final String recipeInstructions;
  final bool isActive;
  final bool isComponent;
  final String notes;
  final DateTime? lastUpdated;
  final List<Ingredient> ingredients;
  final List<PrepTask> prepTasks;
  // New fields for components
  final num? defaultPlannedQuantity;
  final DocumentReference? defaultUnitRef;
  final String? station;

  Dish({
    required this.id,
    required this.dishName,
    required this.recipeInstructions,
    required this.isActive,
    required this.isComponent,
    this.notes = '',
    this.lastUpdated,
    this.ingredients = const [],
    this.prepTasks = const [],
    this.defaultPlannedQuantity,
    this.defaultUnitRef,
    this.station,
  });

  factory Dish.empty({bool isComponent = false}) {
    return Dish(
      id: '',
      dishName: '',
      recipeInstructions: '',
      isActive: true,
      isComponent: isComponent,
      notes: '',
    );
  }

  Dish copyWith({
    String? id,
    String? dishName,
    String? recipeInstructions,
    bool? isActive,
    bool? isComponent,
    String? notes,
    DateTime? lastUpdated,
    List<Ingredient>? ingredients,
    List<PrepTask>? prepTasks,
    num? defaultPlannedQuantity,
    DocumentReference? defaultUnitRef,
    String? station,
  }) {
    return Dish(
      id: id ?? this.id,
      dishName: dishName ?? this.dishName,
      recipeInstructions: recipeInstructions ?? this.recipeInstructions,
      isActive: isActive ?? this.isActive,
      isComponent: isComponent ?? this.isComponent,
      notes: notes ?? this.notes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      ingredients: ingredients ?? this.ingredients,
      prepTasks: prepTasks ?? this.prepTasks,
      defaultPlannedQuantity: defaultPlannedQuantity ?? this.defaultPlannedQuantity,
      defaultUnitRef: defaultUnitRef ?? this.defaultUnitRef,
      station: station ?? this.station,
    );
  }

  factory Dish.fromFirestore(Map<String, dynamic> data, String id) {
    return Dish(
      id: id,
      dishName: data['dishName'] ?? 'Unnamed Dish',
      recipeInstructions: data['recipeInstructions'] ?? '',
      isActive: data['isActive'] ?? true,
      isComponent: data['isComponent'] ?? false,
      notes: data['notes'] ?? '',
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
      defaultPlannedQuantity: data['defaultPlannedQuantity'],
      defaultUnitRef: data['defaultUnitRef'],
      station: data['station'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'dishName': dishName,
      'recipeInstructions': recipeInstructions,
      'isActive': isActive,
      'isComponent': isComponent,
      'notes': notes,
      'lastUpdated': FieldValue.serverTimestamp(),
      'defaultPlannedQuantity': defaultPlannedQuantity,
      'defaultUnitRef': defaultUnitRef,
      'station': station,
    };
  }
}

class Ingredient {
  final String id;
  final DocumentReference inventoryItemRef;
  final DocumentReference? unitRef;
  final num? quantity;
  final IngredientType type;

  Ingredient({
    required this.id,
    required this.inventoryItemRef,
    this.unitRef,
    this.quantity,
    required this.type,
  });

  factory Ingredient.fromFirestore(Map<String, dynamic> data, String id) {
    return Ingredient(
      id: id,
      inventoryItemRef: data['inventoryItemRef'],
      unitRef: data['unitRef'],
      quantity: data['quantity'],
      type: (data['type'] == 'onHand') ? IngredientType.onHand : IngredientType.quantified,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'inventoryItemRef': inventoryItemRef,
      'unitRef': unitRef,
      'quantity': quantity,
      'type': type.name,
    };
  }
}

class PrepTask {
  final String id;
  final String taskName;
  final DocumentReference? linkedDishRef;
  final int order;
  final num plannedQuantity;
  final num completedQuantity;
  final String? unit; // e.g., "Liters", "KG", "Portions"
  final bool isCompleted;
  final String? completedBy;
  final DateTime? completedAt;
  final List<String> parentDishes; // For Mise en Place screen
  final String? station;

  PrepTask({
    required this.id,
    required this.taskName,
    this.linkedDishRef,
    required this.order,
    this.plannedQuantity = 0,
    this.completedQuantity = 0,
    this.unit,
    this.isCompleted = false,
    this.completedBy,
    this.completedAt,
    this.parentDishes = const [],
    this.station,
  });

  PrepTask copyWith({
    String? id,
    String? taskName,
    DocumentReference? linkedDishRef,
    int? order,
    num? plannedQuantity,
    num? completedQuantity,
    String? unit,
    bool? isCompleted,
    String? completedBy,
    DateTime? completedAt,
    List<String>? parentDishes,
    String? station,
  }) {
    return PrepTask(
      id: id ?? this.id,
      taskName: taskName ?? this.taskName,
      linkedDishRef: linkedDishRef ?? this.linkedDishRef,
      order: order ?? this.order,
      plannedQuantity: plannedQuantity ?? this.plannedQuantity,
      completedQuantity: completedQuantity ?? this.completedQuantity,
      unit: unit ?? this.unit,
      isCompleted: isCompleted ?? this.isCompleted,
      completedBy: completedBy ?? this.completedBy,
      completedAt: completedAt ?? this.completedAt,
      parentDishes: parentDishes ?? this.parentDishes,
      station: station ?? this.station,
    );
  }

  factory PrepTask.fromFirestore(Map<String, dynamic> data, String id) {
    return PrepTask(
      id: id,
      taskName: data['taskName'] ?? data['name'] ?? data['dishName'] ?? 'Unnamed Task', // Added 'name' for components
      linkedDishRef: data['linkedDishRef'],
      order: data['order'] ?? 0,
      plannedQuantity: data['plannedQuantity'] ?? 0,
      completedQuantity: data['completedQuantity'] ?? 0,
      unit: data['unit'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'taskName': taskName,
      'linkedDishRef': linkedDishRef,
      'order': order,
      'plannedQuantity': plannedQuantity,
      'completedQuantity': completedQuantity,
      'unit': unit,
    };
  }
}

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
  // These fields are DocumentReferences to maintain data integrity.
  final DocumentReference? supplier;
  final DocumentReference? category;
  final DocumentReference? location;
  final DocumentReference? unit;

  InventoryItem({
    required this.id,
    required this.itemName,
    required this.isButcherItem,
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
      supplier: data['supplier'] as DocumentReference?,
      category: data['category'] as DocumentReference?,
      location: data['location'] as DocumentReference?,
      unit: data['unit'] as DocumentReference?,
    );
  }
}

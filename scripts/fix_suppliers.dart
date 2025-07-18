// scripts/fix_suppliers.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  debugPrint("Initializing Firebase...");

  // Using the specific 'web' configuration from your firebase_options.dart
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "YOUR_API_KEY",
      appId: "1:230443187002:web:e9ad540e7ac9906d71ae03",
      messagingSenderId: "230443187002",
      projectId: "unmercato1",
      authDomain: "unmercato1.firebaseapp.com",
      storageBucket: "unmercato1.firebasestorage.app",
      measurementId: "G-ESP15KG6JQ",
    ),
  );

  debugPrint("Firebase Initialized.");

  final firestore = FirebaseFirestore.instance;
  final batch = firestore.batch();
  int itemsToUpdate = 0;

  try {
    debugPrint("Fetching all suppliers...");
    final suppliersSnapshot = await firestore.collection('suppliers').get();
    final Map<String, DocumentReference> supplierRefsById = {
      for (var doc in suppliersSnapshot.docs) doc.id: doc.reference
    };
    final Map<String, DocumentReference> supplierRefsByName = {
      for (var doc in suppliersSnapshot.docs) (doc.data()['name'] as String) : doc.reference
    };
    debugPrint("Found ${supplierRefsById.length} suppliers.");

    debugPrint("Fetching all inventory items to check them...");
    final inventorySnapshot = await firestore.collection('inventoryItems').get();
    debugPrint("Found ${inventorySnapshot.docs.length} total inventory items.");

    for (final itemDoc in inventorySnapshot.docs) {
      final data = itemDoc.data();
      DocumentReference? correctSupplierRef;

      String? supplierIdString;
      if (data.containsKey('supplierId') && data['supplierId'] is String) {
        supplierIdString = data['supplierId'];
      } else if (data.containsKey('supplier') && data['supplier'] is String) {
        supplierIdString = data['supplier'];
      }

      if (supplierIdString != null) {
        correctSupplierRef = supplierRefsById[supplierIdString] ?? supplierRefsByName[supplierIdString];

        if (correctSupplierRef != null) {
          debugPrint('Fixing item: ${data['itemName']} (id: ${itemDoc.id})');
          batch.update(itemDoc.reference, {'supplier': correctSupplierRef});
          itemsToUpdate++;
        } else {
          debugPrint('Warning: Could not find supplier reference for ID or Name: $supplierIdString for item ${data['itemName']}');
        }
      }
    }

    if (itemsToUpdate > 0) {
      debugPrint("\nFound $itemsToUpdate items to update. Committing changes...");
      await batch.commit();
      debugPrint("Successfully updated $itemsToUpdate items!");
    } else {
      debugPrint("\nNo items needed fixing. All data is in the correct format.");
    }

  } catch (e) {
    debugPrint("\nAn error occurred: $e");
  }

  debugPrint("\nScript finished.");
}
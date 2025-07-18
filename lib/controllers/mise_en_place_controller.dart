import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchen_organizer_app/models/models.dart';

final miseEnPlaceControllerProvider = Provider((ref) => MiseEnPlaceController(ref));

class MiseEnPlaceController {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  MiseEnPlaceController(this._ref);

  Future<String?> toggleTaskCompletion(DocumentReference taskRef, bool currentStatus, DocumentReference? componentRef, String? userId, String? userName) async {
    if (userId == null) return "User not logged in.";

    if (!currentStatus && componentRef != null) {
      // Marking as complete: Run transaction to deduct inventory
      try {
        await _firestore.runTransaction((transaction) async {
          // 1. Fetch all ingredients for the component
          final ingredientsSnapshot = await componentRef.collection('ingredients').get();
          if (ingredientsSnapshot.docs.isEmpty) {
            // No ingredients to deduct, just update the task
            return;
          }

          // 2. For each ingredient, fetch the inventory item and update its quantity
          for (final ingredientDoc in ingredientsSnapshot.docs) {
            final ingredient = Ingredient.fromFirestore(ingredientDoc.data(), ingredientDoc.id);

            // Only deduct for quantified items
            if (ingredient.type == IngredientType.quantified) {
              final inventoryItemRef = ingredient.inventoryItemRef;
              final inventoryItemDoc = await transaction.get(inventoryItemRef);

              if (!inventoryItemDoc.exists) {
                throw Exception("Inventory item ${inventoryItemRef.id} not found!");
              }

              final currentQuantity = (inventoryItemDoc.data()! as Map<String, dynamic>)['quantityOnHand'] ?? 0;
              final quantityToDeduct = ingredient.quantity ?? 0;
              final newQuantity = currentQuantity - quantityToDeduct;

              transaction.update(inventoryItemRef, {'quantityOnHand': newQuantity});
            }
          }

          // 3. Finally, update the task status
          transaction.update(taskRef, {
            'isCompleted': true,
            'completedByUid': userId,
            'completedByName': userName,
            'completedOn': FieldValue.serverTimestamp(),
          });
        });
        return null; // Success
      } catch (e) {
        debugPrint("Transaction failed: $e");
        return "Failed to update inventory: ${e.toString()}";
      }
    } else {
      // Marking as incomplete: Just update the task (no inventory return for now)
      try {
        await taskRef.update({
          'isCompleted': false,
          'completedByUid': FieldValue.delete(),
          'completedByName': FieldValue.delete(),
          'completedOn': FieldValue.delete(),
        });
        return null; // Success
      } catch (e) {
        return "Failed to update task: ${e.toString()}";
      }
    }
  }
}

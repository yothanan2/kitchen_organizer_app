import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kitchen_organizer_app/models/models.dart';

class MiseEnPlaceController {
  final FirebaseFirestore _firestore;

  MiseEnPlaceController(this._firestore);

  Future<String?> toggleTaskCompletion(PrepTask task, bool isCompleted, String? userId, String? userName) async {
    if (userId == null) {
      return 'User not logged in.';
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dailyTaskRef = _firestore.collection('dailyCompletedTasks').doc(today).collection('tasks').doc(task.id);
    final componentRef = _firestore.collection('dishes').doc(task.id);

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Fetch the component's ingredients
        final ingredientsSnapshot = await componentRef.collection('ingredients').get();
        final ingredients = ingredientsSnapshot.docs
            .map((doc) => Ingredient.fromFirestore(doc.data(), doc.id))
            .toList();

        // 2. Update inventory for each ingredient
        for (final ingredient in ingredients) {
          if (ingredient.type == IngredientType.quantified && ingredient.quantity != null && ingredient.quantity! > 0) {
            final inventoryItemDoc = await transaction.get(ingredient.inventoryItemRef);
            if (!inventoryItemDoc.exists) {
              throw Exception("Inventory item ${ingredient.inventoryItemRef.id} not found!");
            }

            final inventoryItemData = inventoryItemDoc.data() as Map<String, dynamic>;
            final currentQuantity = inventoryItemData['quantityOnHand'] ?? 0;

            // Check for sufficient stock ONLY when completing the task
            if (isCompleted && currentQuantity < ingredient.quantity!) {
              final itemName = inventoryItemData['itemName'] ?? 'Unknown Item';
              throw Exception('Insufficient stock for $itemName. Only $currentQuantity available, but ${ingredient.quantity} needed.');
            }

            final change = isCompleted ? -ingredient.quantity! : ingredient.quantity!;
            final newQuantity = currentQuantity + change;

            transaction.update(ingredient.inventoryItemRef, {'quantityOnHand': newQuantity});
          }
        }

        // 3. Update the daily completion status
        if (isCompleted) {
          transaction.set(dailyTaskRef, {
            'isCompleted': true,
            'taskName': task.taskName,
            'completedAt': FieldValue.serverTimestamp(),
            'completedBy': userName ?? 'Unknown User',
            // Store ingredients for potential reversal
            'ingredients': ingredients.map((i) => i.toFirestore()).toList(),
          }, SetOptions(merge: true));
        } else {
          // If un-checking, remove the document
          transaction.delete(dailyTaskRef);
        }
      });
      return null;
    } catch (e) {
      return 'Failed to update task: $e';
    }
  }
}

final miseEnPlaceControllerProvider = Provider<MiseEnPlaceController>((ref) {
  return MiseEnPlaceController(FirebaseFirestore.instance);
});

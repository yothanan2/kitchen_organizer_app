// lib/controllers/edit_dish_controller.dart
// VERSION 3.0: Added full ingredient and saving logic.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../providers.dart';

class EditDishState {
  final AsyncValue<Dish> dish;
  final bool isSaving;

  const EditDishState({
    required this.dish,
    this.isSaving = false,
  });

  EditDishState copyWith({
    AsyncValue<Dish>? dish,
    bool? isSaving,
  }) {
    return EditDishState(
      dish: dish ?? this.dish,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class EditDishController extends StateNotifier<EditDishState> {
  final Ref _ref;
  final Dish? _initialDish;
  final bool _isCreatingComponent;

  EditDishController(this._ref, this._initialDish, this._isCreatingComponent)
      : super(EditDishState(dish: AsyncValue.data(_initialDish ?? Dish.empty(isComponent: _isCreatingComponent)))) {
    _loadDish();
  }

  Future<void> _loadDish() async {
    if (_initialDish == null) return;

    state = state.copyWith(dish: const AsyncValue.loading());

    try {
      final firestore = _ref.read(firestoreProvider);
      final doc = await firestore.collection('dishes').doc(_initialDish!.id).get();

      if (doc.exists) {
        var dish = Dish.fromFirestore(doc.data()!, doc.id);

        final ingredients = await _fetchSubCollection<Ingredient>(doc.reference,
            'ingredients', (data, id) => Ingredient.fromFirestore(data, id));

        final prepTasks = await _fetchSubCollection<PrepTask>(doc.reference,
            'prepTasks', (data, id) => PrepTask.fromFirestore(data, id));

        prepTasks.sort((a, b) => a.order.compareTo(b.order));

        dish = dish.copyWith(ingredients: ingredients, prepTasks: prepTasks);
        state = state.copyWith(dish: AsyncValue.data(dish));
      } else {
        throw Exception("Dish not found");
      }
    } catch (e, st) {
      state = state.copyWith(dish: AsyncValue.error(e, st));
    }
  }

  Future<List<T>> _fetchSubCollection<T>(
      DocumentReference docRef,
      String collectionName,
      T Function(Map<String, dynamic>, String) fromFirestore) async {
    final snapshot = await docRef.collection(collectionName).get();
    return snapshot.docs.map((d) => fromFirestore(d.data(), d.id)).toList();
  }

  void updateDetails({
    String? dishName,
    String? category,
    String? instructions,
    String? notes,
    bool? isActive,
    bool? isComponent,
  }) {
    state.dish.whenData((dish) {
      state = state.copyWith(
        dish: AsyncValue.data(
          dish.copyWith(
            dishName: dishName,
            category: category,
            recipeInstructions: instructions,
            notes: notes,
            isActive: isActive,
            isComponent: isComponent,
          ),
        ),
      );
    });
  }

  void addIngredient(Map<String, dynamic> ingredientData) {
    state.dish.whenData((dish) {
      final firestore = _ref.read(firestoreProvider);
      final newIngredient = Ingredient(
        id: '', // Firestore will generate this
        inventoryItemRef: firestore.collection('inventoryItems').doc(ingredientData['inventoryItemId']),
        quantity: ingredientData['quantity'],
        unitRef: ingredientData['unitId'] != null ? firestore.collection('units').doc(ingredientData['unitId']) : null,
        type: ingredientData['type'] == 'on-hand' ? IngredientType.onHand : IngredientType.quantified,
      );
      final updatedIngredients = List<Ingredient>.from(dish.ingredients)..add(newIngredient);
      state = state.copyWith(dish: AsyncValue.data(dish.copyWith(ingredients: updatedIngredients)));
    });
  }

  void removeIngredient(int index) {
    state.dish.whenData((dish) {
      final updatedIngredients = List<Ingredient>.from(dish.ingredients)..removeAt(index);
      state = state.copyWith(dish: AsyncValue.data(dish.copyWith(ingredients: updatedIngredients)));
    });
  }


  void addPrepTask(PrepTask newTask) {
    state.dish.whenData((dish) {
      final updatedTasks = List<PrepTask>.from(dish.prepTasks)
        ..add(newTask.copyWith(order: dish.prepTasks.length));
      state = state.copyWith(
          dish: AsyncValue.data(dish.copyWith(prepTasks: updatedTasks)));
    });
  }

  void removePrepTask(int index) {
    state.dish.whenData((dish) {
      final updatedTasks = List<PrepTask>.from(dish.prepTasks)..removeAt(index);
      for (int i = 0; i < updatedTasks.length; i++) {
        updatedTasks[i] = updatedTasks[i].copyWith(order: i);
      }
      state = state.copyWith(
          dish: AsyncValue.data(dish.copyWith(prepTasks: updatedTasks)));
    });
  }

  void reorderPrepTasks(int oldIndex, int newIndex) {
    state.dish.whenData((dish) {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final updatedTasks = List<PrepTask>.from(dish.prepTasks);
      final item = updatedTasks.removeAt(oldIndex);
      updatedTasks.insert(newIndex, item);
      for (int i = 0; i < updatedTasks.length; i++) {
        updatedTasks[i] = updatedTasks[i].copyWith(order: i);
      }
      state = state.copyWith(
          dish: AsyncValue.data(dish.copyWith(prepTasks: updatedTasks)));
    });
  }

  Future<String?> saveDish() async {
    final dishToSave = state.dish.value;
    if (dishToSave == null) return "No dish data to save.";
    if (dishToSave.dishName.isEmpty) return "Name cannot be empty.";

    state = state.copyWith(isSaving: true);

    try {
      final firestore = _ref.read(firestoreProvider);
      final collection = firestore.collection('dishes');
      DocumentReference docRef;

      final dishData = dishToSave.toFirestore();

      // If it's a dish (not a component), we only save a limited set of fields.
      if (!dishToSave.isComponent) {
        final simplifiedData = {
          'dishName': dishData['dishName'],
          'isActive': dishData['isActive'],
          'isComponent': false,
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        if (dishToSave.id.isEmpty) {
          await collection.add(simplifiedData);
        } else {
          await collection.doc(dishToSave.id).update(simplifiedData);
        }
        state = state.copyWith(isSaving: false);
        return null; // Early return for simple dishes
      }

      // Full logic for components (with sub-collections)
      if (dishToSave.id.isEmpty) {
        docRef = await collection.add(dishData);
      } else {
        docRef = collection.doc(dishToSave.id);
        await docRef.update(dishData);
      }

      final batch = firestore.batch();

      final ingredientsSnapshot = await docRef.collection('ingredients').get();
      for (final doc in ingredientsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      for (final ingredient in dishToSave.ingredients) {
        batch.set(docRef.collection('ingredients').doc(), ingredient.toFirestore());
      }

      final prepTasksSnapshot = await docRef.collection('prepTasks').get();
      for (final doc in prepTasksSnapshot.docs) {
        batch.delete(doc.reference);
      }
      for (final task in dishToSave.prepTasks) {
        batch.set(docRef.collection('prepTasks').doc(), task.toFirestore());
      }

      await batch.commit();

      state = state.copyWith(isSaving: false);
      return null; // Success
    } catch (e) {
      state = state.copyWith(isSaving: false);
      return "Error saving: $e";
    }
  }
}

// lib/controllers/edit_dish_controller.dart
// VERSION 2.1: Corrected to work with new models.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../providers.dart';

class EditDishState {
  final AsyncValue<Dish?> dish;
  final bool isSaving;

  const EditDishState({
    this.dish = const AsyncValue.loading(),
    this.isSaving = false,
  });

  EditDishState copyWith({
    AsyncValue<Dish?>? dish,
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
  final String? _dishId;
  final bool _isComponent;

  EditDishController(this._ref, this._dishId, this._isComponent)
      : super(const EditDishState()) {
    _loadDish();
  }

  Future<void> _loadDish() async {
    state = state.copyWith(dish: const AsyncValue.loading());
    if (_dishId == null) {
      state = state.copyWith(
        dish: AsyncValue.data(
          Dish(
            id: '',
            dishName: '',
            category: '',
            recipeInstructions: '',
            isActive: true,
            isComponent: _isComponent,
          ),
        ),
      );
      return;
    }

    try {
      final firestore = _ref.read(firestoreProvider);
      final doc = await firestore.collection('dishes').doc(_dishId).get();

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

  void updateField(
      {String? dishName,
        String? category,
        String? recipeInstructions,
        bool? isActive}) {
    state.dish.whenData((dish) {
      if (dish == null) return;
      state = state.copyWith(
        dish: AsyncValue.data(
          dish.copyWith(
            dishName: dishName,
            category: category,
            recipeInstructions: recipeInstructions,
            isActive: isActive,
          ),
        ),
      );
    });
  }

  void addPrepTask(PrepTask newTask) {
    state.dish.whenData((dish) {
      if (dish == null) return;
      final updatedTasks = List<PrepTask>.from(dish.prepTasks)
        ..add(newTask.copyWith(order: dish.prepTasks.length));
      state = state.copyWith(
          dish: AsyncValue.data(dish.copyWith(prepTasks: updatedTasks)));
    });
  }

  void removePrepTask(int index) {
    state.dish.whenData((dish) {
      if (dish == null) return;
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
      if (dish == null) return;
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
}
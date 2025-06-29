// lib/edit_dish_screen.dart
// REFACTORED: This screen is now a ConsumerWidget that uses the EditDishController
// to manage its state and logic, making the UI code much simpler.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'widgets/firestore_name_widget.dart';
import 'providers.dart';
import 'models/models.dart';

class EditDishScreen extends ConsumerStatefulWidget {
  final String? dishId;
  final bool isCreatingComponent;

  const EditDishScreen({
    super.key,
    this.dishId,
    this.isCreatingComponent = false,
  });

  @override
  ConsumerState<EditDishScreen> createState() => _EditDishScreenState();
}

class _EditDishScreenState extends ConsumerState<EditDishScreen> {
  // Controllers for text fields
  final _dishNameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _recipeInstructionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Use a listener to populate controllers once the initial dish data is loaded.
    ref.listenManual<EditDishState>(
      editDishControllerProvider(widget.dishId),
          (previous, next) {
        final dish = next.dish.value;
        if (dish != null) {
          if (_dishNameController.text != dish.dishName) {
            _dishNameController.text = dish.dishName;
          }
          if (_categoryController.text != dish.category) {
            _categoryController.text = dish.category;
          }
          if (_recipeInstructionsController.text != dish.recipeInstructions) {
            _recipeInstructionsController.text = dish.recipeInstructions;
          }
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _dishNameController.dispose();
    _categoryController.dispose();
    _recipeInstructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the state of the controller
    final state = ref.watch(editDishControllerProvider(widget.dishId));
    final controller = ref.read(editDishControllerProvider(widget.dishId).notifier);

    // Use the main AsyncValue to handle loading/error for the whole screen
    return state.dish.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(appBar: AppBar(), body: Center(child: Text('Error loading dish: $err'))),
      data: (dish) {
        if (dish == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Dish not found.')));
        }

        // The main build method for when we have data
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.dishId != null ? 'Edit Dish' : 'Create New Dish'),
            actions: [
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)),
                )
              else
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: () {
                    // Save logic will be added to the controller
                  },
                  tooltip: "Save",
                )
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              // The form key can be handled within the controller if complex validation is needed
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _dishNameController,
                    decoration: InputDecoration(labelText: dish.isComponent ? "Component Name" : "Dish Name", border: const OutlineInputBorder()),
                    validator: (v) => (v == null || v.isEmpty) ? "Please enter a name" : null,
                  ),
                  if (!dish.isComponent) ...[
                    const SizedBox(height: 16),
                    TextFormField(controller: _categoryController, decoration: const InputDecoration(labelText: "Category (e.g., Antipasti)", border: const OutlineInputBorder())),
                  ],
                  // More UI elements will be built from the 'dish' object...
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
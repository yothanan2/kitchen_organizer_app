// lib/edit_dish_screen.dart
// REFACTORED: This screen now uses the EditDishController for all state and logic.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:kitchen_organizer_app/widgets/firestore_name_widget.dart';
import 'package:kitchen_organizer_app/providers.dart';
import 'package:kitchen_organizer_app/models/models.dart';

class EditDishScreen extends ConsumerStatefulWidget {
  final Dish? dish;
  final bool isCreatingComponent;

  const EditDishScreen({
    super.key,
    this.dish,
    this.isCreatingComponent = false,
  });

  @override
  ConsumerState<EditDishScreen> createState() => _EditDishScreenState();
}

class _EditDishScreenState extends ConsumerState<EditDishScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dishNameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _recipeInstructionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Use a listener to populate controllers once the initial dish data is loaded.
    ref.listenManual<EditDishState>(
      editDishControllerProvider((dish: widget.dish, isCreatingComponent: widget.isCreatingComponent)),
          (previous, next) {
        final dish = next.dish.value;
        if (dish != null) {
          if (_dishNameController.text != dish.dishName) _dishNameController.text = dish.dishName;
          if (_categoryController.text != dish.category) _categoryController.text = dish.category;
          if (_recipeInstructionsController.text != dish.recipeInstructions) _recipeInstructionsController.text = dish.recipeInstructions;
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

  Future<void> _showIngredientDialog() async {
    String? selectedInventoryItemId;
    String? selectedUnitId;
    final quantityController = TextEditingController();
    bool isOnHand = false;

    Future<List<DocumentSnapshot>> getInventoryItems(String? filter) async {
      return (await FirebaseFirestore.instance.collection('inventoryItems').orderBy('itemName').get()).docs;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final newItemData = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Add Ingredient"),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownSearch<DocumentSnapshot>(
                  asyncItems: getInventoryItems,
                  itemAsString: (doc) => (doc.data() as Map<String, dynamic>)['itemName'],
                  popupProps: const PopupProps.menu(showSearchBox: true),
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(labelText: "Select Inventory Item"),
                  ),
                  onChanged: (newlySelectedDoc) {
                    if (newlySelectedDoc != null) {
                      final data = newlySelectedDoc.data() as Map<String, dynamic>?;
                      setDialogState(() {
                        selectedInventoryItemId = newlySelectedDoc.id;
                        selectedUnitId = (data?['unit'] as DocumentReference?)?.id;
                      });
                    }
                  },
                ),
                CheckboxListTile(
                  title: const Text("'On-Hand' Item?"),
                  value: isOnHand,
                  onChanged: (newValue) => setDialogState(() => isOnHand = newValue ?? false),
                ),
                if (!isOnHand) ...[
                  TextField(controller: quantityController, decoration: const InputDecoration(labelText: "Quantity"), keyboardType: TextInputType.number),
                  // In a future step, we could make this unit dropdown more robust.
                ]
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
              ElevatedButton(
                child: const Text("Save"),
                onPressed: () {
                  bool isValid = selectedInventoryItemId != null && (isOnHand || (quantityController.text.isNotEmpty));
                  if (isValid) {
                    Navigator.of(context).pop({
                      'inventoryItemId': selectedInventoryItemId,
                      'quantity': isOnHand ? null : num.tryParse(quantityController.text),
                      'unitId': isOnHand ? null : selectedUnitId,
                      'type': isOnHand ? 'on-hand' : 'quantified'
                    });
                  } else {
                    scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Please fill all required fields.")));
                  }
                },
              ),
            ],
          );
        });
      },
    );
    if (newItemData != null) {
      ref.read(editDishControllerProvider((dish: widget.dish, isCreatingComponent: widget.isCreatingComponent)).notifier).addIngredient(newItemData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = editDishControllerProvider((dish: widget.dish, isCreatingComponent: widget.isCreatingComponent));
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    return state.dish.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(appBar: AppBar(), body: Center(child: Text('Error loading dish: $err'))),
      data: (dish) {
        return Scaffold(
          appBar: AppBar(
            title: Text(dish.id.isNotEmpty ? 'Edit Dish' : 'Create New Dish'),
            actions: [
              if (state.isSaving)
                const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white))
              else
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;

                    controller.updateDetails(
                      dishName: _dishNameController.text,
                      category: _categoryController.text,
                      instructions: _recipeInstructionsController.text,
                    );

                    final error = await controller.saveDish();
                    if (mounted) {
                      if (error == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dish saved successfully!'), backgroundColor: Colors.green));
                        Navigator.of(context).pop();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                      }
                    }
                  },
                  tooltip: "Save",
                )
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _dishNameController,
                    decoration: InputDecoration(labelText: dish.isComponent ? "Component Name" : "Dish Name"),
                    validator: (v) => (v == null || v.isEmpty) ? "Please enter a name" : null,
                  ),
                  if (!dish.isComponent) ...[
                    const SizedBox(height: 16),
                    TextFormField(controller: _categoryController, decoration: const InputDecoration(labelText: "Category")),
                  ],
                  const SizedBox(height: 16),
                  Card(
                    child: SwitchListTile(
                      title: const Text("Is a Component"),
                      subtitle: const Text("Can be used in other recipes."),
                      value: dish.isComponent,
                      onChanged: (value) => controller.updateDetails(isComponent: value),
                    ),
                  ),
                  if (!dish.isComponent)
                    Card(
                      child: SwitchListTile(
                        title: const Text("Is Active"),
                        subtitle: const Text("Appears on menus and lists."),
                        value: dish.isActive,
                        onChanged: (value) => controller.updateDetails(isActive: value),
                      ),
                    ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Ingredients", style: Theme.of(context).textTheme.titleMedium),
                      ElevatedButton.icon(onPressed: _showIngredientDialog, icon: const Icon(Icons.add), label: const Text("Add"))
                    ],
                  ),
                  if (dish.ingredients.isEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Center(child: Text("No ingredients added.")))
                  else
                    ...dish.ingredients.map((ingredient) {
                      final index = dish.ingredients.indexOf(ingredient);
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.fiber_manual_record, size: 10),
                        title: FirestoreNameWidget(collection: 'inventoryItems', docId: ingredient.inventoryItemRef.id, fieldName: 'itemName'),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => controller.removeIngredient(index)),
                      );
                    }),

                  const SizedBox(height: 24),
                  Text("Recipe Instructions", style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _recipeInstructionsController,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    maxLines: 10,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
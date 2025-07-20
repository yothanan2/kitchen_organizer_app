// lib/edit_dish_screen.dart
// REFACTORED: This screen now uses the EditDishController for all state and logic.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:kitchen_organizer_app/controllers/edit_dish_controller.dart';
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
  final _recipeInstructionsController = TextEditingController();
  final _notesController = TextEditingController();
  final _defaultQuantityController = TextEditingController();

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
          if (_recipeInstructionsController.text != dish.recipeInstructions) _recipeInstructionsController.text = dish.recipeInstructions;
          if (_notesController.text != dish.notes) _notesController.text = dish.notes;
          if (dish.defaultPlannedQuantity != null) {
            _defaultQuantityController.text = dish.defaultPlannedQuantity.toString();
          }
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _dishNameController.dispose();
    _recipeInstructionsController.dispose();
    _notesController.dispose();
    _defaultQuantityController.dispose();
    super.dispose();
  }

  Future<void> _showComponentDialog() async {
    DocumentSnapshot? selectedComponent;

    Future<List<DocumentSnapshot>> getComponents(String? filter) async {
      final query = FirebaseFirestore.instance
          .collection('dishes')
          .where('isComponent', isEqualTo: true)
          .orderBy('dishName');
      return (await query.get()).docs;
    }

    final newComponent = await showDialog<DocumentSnapshot>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Component"),
          content: DropdownSearch<DocumentSnapshot>(
            asyncItems: getComponents,
            itemAsString: (doc) => (doc.data() as Map<String, dynamic>)['dishName'],
            popupProps: const PopupProps.menu(showSearchBox: true),
            dropdownDecoratorProps: const DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(labelText: "Select Component"),
            ),
            onChanged: (newlySelectedDoc) {
              selectedComponent = newlySelectedDoc;
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
            ElevatedButton(
              child: const Text("Add"),
              onPressed: () {
                Navigator.of(context).pop(selectedComponent);
              },
            ),
          ],
        );
      },
    );

    if (newComponent != null) {
      final componentData = newComponent.data() as Map<String, dynamic>;
      final unitRef = componentData['defaultUnitRef'] as DocumentReference?;
      String? unitName;

      // Fetch the unit name from the reference
      if (unitRef != null) {
        try {
          final unitDoc = await unitRef.get();
          if (unitDoc.exists) {
            unitName = (unitDoc.data() as Map<String, dynamic>)['name'];
          }
        } catch (e) {
          debugPrint("Error fetching unit name: $e");
        }
      }

      final newTask = PrepTask(
        id: newComponent.id,
        taskName: componentData['dishName'] ?? 'Unnamed Component',
        linkedDishRef: newComponent.reference,
        order: 0, // Controller will handle reordering
        plannedQuantity: (componentData['defaultPlannedQuantity'] as num?) ?? 1, // Default to 1 if null
        unit: unitName,
      );
      ref.read(editDishControllerProvider((dish: widget.dish, isCreatingComponent: widget.isCreatingComponent)).notifier).addPrepTask(newTask);
    }
  }

  Future<void> _showIngredientDialog() async {
    String? selectedInventoryItemId;
    DocumentSnapshot? selectedUnitDoc; // Changed to hold the full DocumentSnapshot
    final quantityController = TextEditingController();
    bool isOnHand = false;

    Future<List<DocumentSnapshot>> getInventoryItems(String? filter) async {
      return (await FirebaseFirestore.instance.collection('inventoryItems').orderBy('itemName').get()).docs;
    }

    // New function to get units
    Future<List<DocumentSnapshot>> getUnits(String? filter) async {
      return (await FirebaseFirestore.instance.collection('units').orderBy('name').get()).docs;
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
                  onChanged: (newlySelectedDoc) async {
                    if (newlySelectedDoc != null) {
                      final data = newlySelectedDoc.data() as Map<String, dynamic>?;
                      final unitRef = data?['unit'] as DocumentReference?;
                      DocumentSnapshot? unitDoc;
                      if (unitRef != null) {
                        unitDoc = await unitRef.get();
                      }
                      setDialogState(() {
                        selectedInventoryItemId = newlySelectedDoc.id;
                        selectedUnitDoc = unitDoc; // Store the whole doc
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
                  const SizedBox(height: 16),
                  DropdownSearch<DocumentSnapshot>(
                    asyncItems: getUnits,
                    itemAsString: (doc) => (doc.data() as Map<String, dynamic>)['name'],
                    selectedItem: selectedUnitDoc, // Pre-select the unit
                    popupProps: const PopupProps.menu(showSearchBox: true),
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(labelText: "Unit"),
                    ),
                    onChanged: (newlySelectedUnit) {
                      setDialogState(() {
                        selectedUnitDoc = newlySelectedUnit;
                      });
                    },
                  ),
                ]
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
              ElevatedButton(
                child: const Text("Save"),
                onPressed: () {
                  // Updated validation to include unit selection
                  bool isValid = selectedInventoryItemId != null && (isOnHand || (quantityController.text.isNotEmpty && selectedUnitDoc != null));
                  if (isValid) {
                    Navigator.of(context).pop({
                      'inventoryItemId': selectedInventoryItemId,
                      'quantity': isOnHand ? null : num.tryParse(quantityController.text),
                      'unitId': isOnHand ? null : selectedUnitDoc?.id, // Pass the id from the selected doc
                      'type': isOnHand ? 'on-hand' : 'quantified'
                    });
                  } else {
                    scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Please fill all required fields, including the unit.")));
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
        final bool isComponent = widget.isCreatingComponent || dish.isComponent;

        return Scaffold(
          appBar: AppBar(
            title: Text(dish.id.isNotEmpty ? 'Edit ${isComponent ? "Component" : "Dish"}' : 'Create New ${isComponent ? "Component" : "Dish"}'),
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
                      instructions: _recipeInstructionsController.text,
                      notes: _notesController.text,
                      defaultPlannedQuantity: num.tryParse(_defaultQuantityController.text),
                    );

                    final error = await controller.saveDish();
                    if (!context.mounted) return;
                    if (error == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully!'), backgroundColor: Colors.green));
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                    }
                  },
                  tooltip: "Save",
                )
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _dishNameController,
                    decoration: InputDecoration(labelText: isComponent ? "Component Name" : "Dish Name"),
                    validator: (v) => (v == null || v.isEmpty) ? "Please enter a name" : null,
                  ),
                  if (!isComponent) ...[
                    const SizedBox(height: 16),
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
                        Text("Components", style: Theme.of(context).textTheme.titleMedium),
                        ElevatedButton.icon(onPressed: _showComponentDialog, icon: const Icon(Icons.add), label: const Text("Add"))
                      ],
                    ),
                    if (dish.prepTasks.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Center(child: Text("No components added.")))
                    else
                      ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: dish.prepTasks.map((task) {
                          return ListTile(
                            key: ValueKey(task.id),
                            dense: true,
                            leading: const Icon(Icons.drag_handle),
                            title: Text(task.taskName),
                            trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => controller.removePrepTask(dish.prepTasks.indexOf(task))),
                          );
                        }).toList(),
                        onReorder: (oldIndex, newIndex) {
                          controller.reorderPrepTasks(oldIndex, newIndex);
                        },
                      ),
                  ],
                  if (isComponent) ...[
                    const SizedBox(height: 16),
                    Text("Default Prep Amount", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _defaultQuantityController,
                            decoration: const InputDecoration(labelText: "Default Quantity", border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v != null && v.isNotEmpty && num.tryParse(v) == null) {
                                return "Must be a valid number";
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Consumer(builder: (context, ref, child) {
                            final unitsAsync = ref.watch(unitsStreamProvider);
                            return unitsAsync.when(
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (err, stack) => Text('Error: $err'),
                              data: (unitsSnapshot) {
                                return DropdownButtonFormField<DocumentReference>(
                                  value: dish.defaultUnitRef,
                                  decoration: const InputDecoration(labelText: "Unit", border: OutlineInputBorder()),
                                  items: unitsSnapshot.docs.map((doc) {
                                    return DropdownMenuItem<DocumentReference>(
                                      value: doc.reference,
                                      child: Text((doc.data() as Map<String, dynamic>)['name']),
                                    );
                                  }).toList(),
                                  onChanged: (value) => controller.updateDetails(defaultUnitRef: value),
                                );
                              },
                            );
                          }),
                        ),
                      ],
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
                          title: FirestoreNameWidget(
                            docRef: ingredient.inventoryItemRef,
                            builder: (context, name) => Text(name),
                          ),
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
                  const SizedBox(height: 24),
                  Text("Notes", style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    maxLines: 5,
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

final editDishControllerProvider = StateNotifierProvider.family<EditDishController, EditDishState, ({Dish? dish, bool isCreatingComponent})>((ref, params) {
  return EditDishController(ref, params.dish, params.isCreatingComponent);
});
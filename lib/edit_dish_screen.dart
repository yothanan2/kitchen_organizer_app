// lib/edit_dish_screen.dart
// UPDATED: Now hides detailed sections when creating a new dish for a simpler workflow.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'widgets/firestore_name_widget.dart';

class EditDishScreen extends StatefulWidget {
  final DocumentSnapshot? dishDocument;
  final bool isCreatingComponent;

  const EditDishScreen({
    super.key,
    this.dishDocument,
    this.isCreatingComponent = false,
  });

  @override
  State<EditDishScreen> createState() => _EditDishScreenState();
}

class _EditDishScreenState extends State<EditDishScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dishNameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _recipeInstructionsController = TextEditingController();

  List<Map<String, dynamic>> _ingredients = [];
  List<Map<String, dynamic>> _prepTasks = [];

  bool _isActive = true;
  bool _isComponent = false;

  bool _isLoading = false;
  bool get _isEditing => widget.dishDocument != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final data = widget.dishDocument!.data() as Map<String, dynamic>;
      _dishNameController.text = data['dishName'] ?? '';
      _categoryController.text = data['category'] ?? '';
      _recipeInstructionsController.text = data['recipeInstructions'] ?? '';
      _isActive = data['isActive'] ?? true;
      _isComponent = data['isComponent'] ?? false;
      _loadSubCollections();
    } else {
      _isComponent = widget.isCreatingComponent;
    }
  }

  Future<void> _loadSubCollections() async {
    if (!_isEditing || !mounted) return;
    final ingredientsSnapshot = await widget.dishDocument!.reference.collection('ingredients').get();
    if (!mounted) return;
    final loadedIngredients = ingredientsSnapshot.docs.map((doc) {
      final data = doc.data();
      final inventoryItemId = (data['inventoryItemRef'] as DocumentReference).id;
      return {'id': doc.id, 'inventoryItemId': inventoryItemId, 'quantity': data['quantity'], 'unitId': (data['unitId'] as DocumentReference?)?.id, 'type': data['type'] ?? 'quantified'};
    }).toList();
    final prepTasksSnapshot = await widget.dishDocument!.reference.collection('prepTasks').orderBy('order').get();
    if (!mounted) return;
    final loadedPrepTasks = prepTasksSnapshot.docs.map((doc) {
      final data = doc.data();
      final linkedDishRef = data['linkedDishRef'] as DocumentReference?;
      return {'id': doc.id, 'taskName': data['taskName'], 'linkedDishId': linkedDishRef?.id, 'order': data['order'] ?? 0};
    }).toList();
    if (mounted) {
      setState(() {
        _ingredients = loadedIngredients;
        _prepTasks = loadedPrepTasks;
      });
    }
  }

  Future<void> _showIngredientDialog({int? editIndex}) async {
    final bool isEditingIngredient = editIndex != null;
    final Map<String, dynamic>? ingredientToEdit = isEditingIngredient ? _ingredients[editIndex!] : null;

    String? selectedInventoryItemId = ingredientToEdit?['inventoryItemId'];
    String? selectedUnitId = ingredientToEdit?['unitId'];
    final quantityController = TextEditingController(text: ingredientToEdit?['quantity']?.toString() ?? '');
    bool isOnHand = ingredientToEdit?['type'] == 'on-hand';

    Future<List<DocumentSnapshot>> getInventoryItems(String? filter) async {
      final snapshot = await FirebaseFirestore.instance.collection('inventoryItems').orderBy('itemName').get();
      return snapshot.docs;
    }

    DocumentSnapshot? selectedDoc;
    if (isEditingIngredient && selectedInventoryItemId != null) {
      final docGet = await FirebaseFirestore.instance.collection('inventoryItems').doc(selectedInventoryItemId).get();
      if (docGet.exists) {
        selectedDoc = docGet;
      }
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final newItemData = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditingIngredient ? "Edit Ingredient" : "Add Ingredient"),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownSearch<DocumentSnapshot>(
                  asyncItems: getInventoryItems,
                  itemAsString: (DocumentSnapshot doc) => (doc.data() as Map<String, dynamic>)['itemName'] as String,
                  selectedItem: selectedDoc,
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(decoration: InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), hintText: "Search for an ingredient...")),
                    menuProps: MenuProps(elevation: 8),
                  ),
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(labelText: "Select Inventory Item", border: OutlineInputBorder()),
                  ),
                  onChanged: (DocumentSnapshot? newlySelectedDoc) {
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
                  subtitle: const Text("(No specific quantity needed)"),
                  value: isOnHand,
                  onChanged: (newValue) => setDialogState(() => isOnHand = newValue ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (!isOnHand) ...[
                  const SizedBox(height: 8),
                  TextField(controller: quantityController, decoration: const InputDecoration(labelText: "Quantity"), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('units').orderBy('name').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final unitItems = snapshot.data!.docs.map((doc) => DropdownMenuItem<String>(value: doc.id, child: Text((doc.data() as Map<String, dynamic>)['name']))).toList();
                      final bool unitExists = unitItems.any((item) => item.value == selectedUnitId);
                      return DropdownButtonFormField<String>(
                        value: unitExists ? selectedUnitId : null, hint: const Text("Select Unit"), items: unitItems,
                        onChanged: (newValue) => setDialogState(() => selectedUnitId = newValue),
                      );
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
                  bool isQuantifiedValid = !isOnHand && quantityController.text.isNotEmpty && selectedUnitId != null;
                  bool isOnHandValid = isOnHand;
                  if (selectedInventoryItemId != null && (isQuantifiedValid || isOnHandValid)) {
                    Navigator.of(context).pop({'inventoryItemId': selectedInventoryItemId, 'quantity': isOnHand ? null : num.tryParse(quantityController.text) ?? 0, 'unitId': isOnHand ? null : selectedUnitId, 'type': isOnHand ? 'on-hand' : 'quantified'});
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
    if (newItemData != null && mounted) {
      setState(() {
        if (isEditingIngredient) {
          _ingredients[editIndex!] = newItemData;
        } else {
          _ingredients.add(newItemData);
        }
      });
    }
  }

  void _showPrepTaskDialog({int? index}) async {
    final taskToEdit = (index != null) ? _prepTasks[index] : null;
    final taskController = TextEditingController(text: taskToEdit?['taskName'] ?? '');
    String? linkedDishId = taskToEdit?['linkedDishId'];

    Future<List<DocumentSnapshot>> getComponentRecipes(String? filter) async {
      final snapshot = await FirebaseFirestore.instance
          .collection('dishes')
          .where('isComponent', isEqualTo: true)
          .orderBy('dishName')
          .get();
      return snapshot.docs;
    }

    DocumentSnapshot? selectedDoc;
    if (linkedDishId != null) {
      final docGet = await FirebaseFirestore.instance.collection('dishes').doc(linkedDishId).get();
      if (docGet.exists) {
        selectedDoc = docGet;
      }
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(taskToEdit == null ? "Add Component / Step" : "Edit Component / Step"),
        content: StatefulBuilder(builder: (context, setDialogState) {
          return SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: taskController, decoration: const InputDecoration(labelText: "Step Name", hintText: "e.g., Slice tomatoes"), autofocus: true),
                  const SizedBox(height: 24),
                  const Text("Link to a Recipe (Optional)", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownSearch<DocumentSnapshot>(
                    asyncItems: getComponentRecipes,
                    itemAsString: (DocumentSnapshot doc) => (doc.data() as Map<String, dynamic>)['dishName'] as String,
                    selectedItem: selectedDoc,
                    popupProps: const PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(decoration: InputDecoration(border: OutlineInputBorder(), hintText: "Search for a recipe...")),
                    ),
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(labelText: "Select Recipe", border: OutlineInputBorder()),
                    ),
                    onChanged: (DocumentSnapshot? newlySelectedDoc) {
                      setDialogState(() {
                        linkedDishId = newlySelectedDoc?.id;
                      });
                    },
                    clearButtonProps: const ClearButtonProps(isVisible: true),
                  ),
                ]),
          );
        }),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (taskController.text.trim().isNotEmpty) {
                Navigator.of(context).pop({'taskName': taskController.text.trim(), 'linkedDishId': linkedDishId});
              } else {
                scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Please enter a name for the step.")));
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (index == null) {
          result['order'] = _prepTasks.length;
          _prepTasks.add(result);
        } else {
          result['order'] = _prepTasks[index]['order'];
          _prepTasks[index] = result;
        }
      });
    }
  }

  Future<void> _saveDish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final dishData = {'dishName': _dishNameController.text.trim(), 'category': _categoryController.text.trim(), 'recipeInstructions': _recipeInstructionsController.text.trim(), 'isActive': _isActive, 'isComponent': _isComponent, 'lastUpdated': FieldValue.serverTimestamp()};
    try {
      DocumentReference dishRef;
      if (_isEditing) {
        dishRef = widget.dishDocument!.reference;
        await dishRef.update(dishData);
      } else {
        dishRef = await FirebaseFirestore.instance.collection('dishes').add(dishData);
      }
      final batch = FirebaseFirestore.instance.batch();
      final oldIngredients = await dishRef.collection('ingredients').get();
      for (final doc in oldIngredients.docs) { batch.delete(doc.reference); }
      for (final ingredient in _ingredients) {
        final ingredientRef = dishRef.collection('ingredients').doc();
        final unitRef = ingredient['unitId'] != null ? FirebaseFirestore.instance.collection('units').doc(ingredient['unitId']) : null;
        batch.set(ingredientRef, {'inventoryItemRef': FirebaseFirestore.instance.collection('inventoryItems').doc(ingredient['inventoryItemId']), 'quantity': ingredient['quantity'], 'unitId': unitRef, 'type': ingredient['type']});
      }
      final oldPrepTasks = await dishRef.collection('prepTasks').get();
      for (final doc in oldPrepTasks.docs) { batch.delete(doc.reference); }
      for (final task in _prepTasks) {
        final taskRef = dishRef.collection('prepTasks').doc();
        batch.set(taskRef, {'taskName': task['taskName'], 'linkedDishRef': task['linkedDishId'] != null ? FirebaseFirestore.instance.collection('dishes').doc(task['linkedDishId']) : null, 'order': task['order']});
      }
      await batch.commit();

      scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Dish saved successfully!")));
      navigator.pop();

    } catch(e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text("Failed to save dish: $e")));
    } finally {
      if(mounted) setState(() { _isLoading = false; });
    }
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
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing
              ? (_isComponent ? 'Edit Component' : 'Edit Dish')
              : (_isComponent ? 'Create New Component' : 'Create New Dish')
          ),
          actions: [IconButton(onPressed: _isLoading ? null : _saveDish, icon: const Icon(Icons.save), tooltip: "Save")]
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(controller: _dishNameController, decoration: InputDecoration(labelText: _isComponent ? "Component Name" : "Dish Name", border: const OutlineInputBorder()), validator: (v) => (v == null || v.isEmpty) ? "Please enter a name" : null),

              // --- MODIFICATION START ---
              // Only show these fields if editing, not creating a new dish.
              if (_isEditing) ...[
                const SizedBox(height: 16),
                TextFormField(controller: _categoryController, decoration: const InputDecoration(labelText: "Category (e.g., Antipasti)", border: OutlineInputBorder())),
              ],

              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    // Only show "Is Component" if editing or explicitly creating a component
                    if (_isEditing || widget.isCreatingComponent)
                      SwitchListTile(
                        title: const Text("Is a Component"),
                        subtitle: const Text("Components (like sauces or bases) can be selected in other recipes."),
                        value: _isComponent,
                        onChanged: (value) => setState(() => _isComponent = value),
                      ),
                    if (!_isComponent)
                      SwitchListTile(
                        title: const Text("Is Active"),
                        subtitle: const Text("Active dishes appear in standard lists."),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                  ],
                ),
              ),

              if (_isEditing) ...[
                const SizedBox(height: 24),
                _buildSectionHeader("Ingredients", () => _showIngredientDialog()),
                _ingredients.isEmpty
                    ? const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Center(child: Text("No ingredients added.")))
                    : ListView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _ingredients.length,
                  itemBuilder: (context, index) {
                    final ingredient = _ingredients[index];
                    final bool isOnHand = ingredient['type'] == 'on-hand';
                    return ListTile(
                      title: FirestoreNameWidget(collection: 'inventoryItems', docId: ingredient['inventoryItemId'], fieldName: 'itemName'),
                      subtitle: isOnHand ? const Text("On-Hand Item", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blue)) : Row(mainAxisSize: MainAxisSize.min, children: [Text(ingredient['quantity'].toString()), const SizedBox(width: 4), FirestoreNameWidget(collection: 'units', docId: ingredient['unitId'])]),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey), onPressed: () => _showIngredientDialog(editIndex: index)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() => _ingredients.removeAt(index))),
                        ],
                      ),
                    );
                  },
                ),

                if (!_isComponent) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader("Dish Components / Prep Steps", () => _showPrepTaskDialog(index: null)),
                  if (_prepTasks.isEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Center(child: Text("No components or steps added.")))
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _prepTasks.length,
                      itemBuilder: (context, index) {
                        final task = _prepTasks[index];
                        return Card(
                          key: ValueKey(task['taskName']! + index.toString()),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.drag_handle, color: Colors.grey),
                            title: Text(task['taskName'] ?? ''),
                            subtitle: task['linkedDishId'] != null ? Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.link, size: 12, color: Colors.grey), const SizedBox(width: 4), FirestoreNameWidget(collection: 'dishes', docId: task['linkedDishId'], fieldName: 'dishName', defaultText: "Linked Recipe")]) : null,
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey), onPressed: () => _showPrepTaskDialog(index: index)),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() => _prepTasks.removeAt(index))),
                            ]),
                          ),
                        );
                      },
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final item = _prepTasks.removeAt(oldIndex);
                          _prepTasks.insert(newIndex, item);
                          for (int i = 0; i < _prepTasks.length; i++) {
                            _prepTasks[i]['order'] = i;
                          }
                        });
                      },
                    ),
                ],

                const SizedBox(height: 24),
                const Text("Recipe Instructions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(controller: _recipeInstructionsController, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "1. Combine all ingredients..."), maxLines: 10),
              ],
              // --- MODIFICATION END ---
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onAdd) {
    final buttonText = title == "Ingredients" ? "Add" : "Add Component / Step";
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(buttonText))]);
  }
}
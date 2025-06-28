// lib/add_edit_recipe_screen.dart
// CORRECTED: Updated the import to use the central FirestoreNameWidget.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';

// CORRECTED: Import the new reusable widget.
import 'widgets/firestore_name_widget.dart';

class AddEditRecipeScreen extends StatefulWidget {
  final DocumentSnapshot? recipeDocument;

  const AddEditRecipeScreen({super.key, this.recipeDocument});

  @override
  State<AddEditRecipeScreen> createState() => _AddEditRecipeScreenState();
}

class _AddEditRecipeScreenState extends State<AddEditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _recipeInstructionsController = TextEditingController();

  List<Map<String, dynamic>> _ingredients = [];

  bool _isLoading = false;
  bool get _isEditing => widget.recipeDocument != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final data = widget.recipeDocument!.data() as Map<String, dynamic>;
      _nameController.text = data['dishName'] ?? '';
      _recipeInstructionsController.text = data['recipeInstructions'] ?? '';
      _loadIngredients();
    }
  }

  Future<void> _loadIngredients() async {
    if (!_isEditing) return;
    final ingredientsSnapshot = await widget.recipeDocument!.reference.collection('ingredients').get();
    if (!mounted) return;
    final loadedIngredients = ingredientsSnapshot.docs.map((doc) {
      final data = doc.data();
      final inventoryItemId = (data['inventoryItemRef'] as DocumentReference).id;
      return {'id': doc.id, 'inventoryItemId': inventoryItemId, 'quantity': data['quantity'], 'unitId': (data['unitId'] as DocumentReference?)?.id, 'type': data['type'] ?? 'quantified'};
    }).toList();

    if (mounted) {
      setState(() {
        _ingredients = loadedIngredients;
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

    // Capture context before the async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

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
                  onChanged: (DocumentSnapshot? newlySelectedDoc) async {
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

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final recipeData = {
      'dishName': _nameController.text.trim(),
      'recipeInstructions': _recipeInstructionsController.text.trim(),
      'isComponent': true,
      'isActive': true,
      'category': '',
      'lastUpdated': FieldValue.serverTimestamp()
    };
    try {
      DocumentReference recipeRef;
      if (_isEditing) {
        recipeRef = widget.recipeDocument!.reference;
        await recipeRef.update(recipeData);
      } else {
        recipeRef = await FirebaseFirestore.instance.collection('dishes').add(recipeData);
      }
      final batch = FirebaseFirestore.instance.batch();
      final oldIngredients = await recipeRef.collection('ingredients').get();
      for (final doc in oldIngredients.docs) { batch.delete(doc.reference); }
      for (final ingredient in _ingredients) {
        final ingredientRef = recipeRef.collection('ingredients').doc();
        final unitRef = ingredient['unitId'] != null ? FirebaseFirestore.instance.collection('units').doc(ingredient['unitId']) : null;
        batch.set(ingredientRef, {'inventoryItemRef': FirebaseFirestore.instance.collection('inventoryItems').doc(ingredient['inventoryItemId']), 'quantity': ingredient['quantity'], 'unitId': unitRef, 'type': ingredient['type']});
      }
      await batch.commit();

      scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Recipe saved successfully!")));
      navigator.pop();

    } catch(e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text("Failed to save recipe: $e")));
    } finally {
      if(mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _recipeInstructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? "Edit Recipe" : "Create New Recipe"), actions: [IconButton(onPressed: _isLoading ? null : _saveRecipe, icon: const Icon(Icons.save), tooltip: "Save Recipe")]),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: "Recipe Name (e.g., Balsamic Vinaigrette)", border: OutlineInputBorder()), validator: (v) => (v == null || v.isEmpty) ? "Please enter a recipe name" : null),
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
              const SizedBox(height: 24),
              const Text("Recipe Instructions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(controller: _recipeInstructionsController, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "1. Combine all ingredients..."), maxLines: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onAdd) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text("Add"))]);
  }
}
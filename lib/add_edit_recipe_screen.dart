// lib/add_edit_recipe_screen.dart
// VERSION 5: Final fix for all typos and errors.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'widgets/firestore_name_widget.dart';

class AddEditRecipeScreen extends StatefulWidget {
  final DocumentSnapshot? dishDocument;
  final bool isComponent;

  const AddEditRecipeScreen({
    super.key,
    this.dishDocument,
    this.isComponent = false,
  });

  @override
  State<AddEditRecipeScreen> createState() => _AddEditRecipeScreenState();
}

class _AddEditRecipeScreenState extends State<AddEditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _recipeInstructionsController = TextEditingController();
  final _categoryController = TextEditingController();

  List<Map<String, dynamic>> _ingredients = [];
  List<Map<String, dynamic>> _prepTasks = [];

  bool _isLoading = false;
  bool _isActive = true;
  late bool _isComponent;

  bool get _isEditing => widget.dishDocument != null;

  @override
  void initState() {
    super.initState();
    _isComponent = widget.isComponent;

    if (_isEditing) {
      final data = widget.dishDocument!.data() as Map<String, dynamic>;
      _nameController.text = data['dishName'] ?? '';
      _recipeInstructionsController.text = data['recipeInstructions'] ?? '';
      _categoryController.text = data['category'] ?? '';
      _isComponent = data['isComponent'] ?? false;
      _isActive = data['isActive'] ?? true;
      _loadSubCollections();
    }
  }

  Future<void> _loadSubCollections() async {
    if (!_isEditing) return;
    final docRef = widget.dishDocument!.reference;

    final ingredientsSnapshot = await docRef.collection('ingredients').get();
    if (mounted) {
      setState(() {
        _ingredients = ingredientsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'inventoryItemRef': data['inventoryItemRef'] as DocumentReference,
            'quantity': data['quantity'],
            'unitRef': data['unitId'] as DocumentReference?,
            'type': data['type'] ?? 'quantified'
          };
        }).toList();
      });
    }

    final prepTasksSnapshot =
    await docRef.collection('prepTasks').orderBy('order').get();
    if (mounted) {
      setState(() {
        _prepTasks = prepTasksSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'taskName': data['taskName'],
            'linkedDishRef': data['linkedDishRef'] as DocumentReference?,
            'order': data['order'] ?? 0
          };
        }).toList();
      });
    }
  }

  Future<void> _showIngredientDialog({int? editIndex}) async {
    final bool isEditingIngredient = editIndex != null;
    final Map<String, dynamic>? ingredientToEdit =
    isEditingIngredient ? _ingredients[editIndex!] : null;

    DocumentReference? selectedInventoryItemRef =
    ingredientToEdit?['inventoryItemRef'];
    DocumentReference? selectedUnitRef = ingredientToEdit?['unitRef'];
    final quantityController =
    TextEditingController(text: ingredientToEdit?['quantity']?.toString() ?? '');
    String ingredientType = ingredientToEdit?['type'] ?? 'quantified';

    DocumentSnapshot? initialItemDoc;
    if (selectedInventoryItemRef != null) {
      initialItemDoc = await selectedInventoryItemRef.get();
    }

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title:
            Text(isEditingIngredient ? "Edit Ingredient" : "Add Ingredient"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownSearch<DocumentSnapshot>(
                    asyncItems: (String? filter) => FirebaseFirestore.instance
                        .collection('inventoryItems')
                        .orderBy('itemName')
                        .get()
                        .then((snapshot) => snapshot.docs),
                    itemAsString: (DocumentSnapshot doc) =>
                    (doc.data() as Map<String, dynamic>)['itemName']
                    as String,
                    selectedItem: initialItemDoc,
                    popupProps: const PopupProps.menu(showSearchBox: true),
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                          labelText: "Select Inventory Item",
                          border: OutlineInputBorder()),
                    ),
                    onChanged: (DocumentSnapshot? doc) {
                      if (doc != null) {
                        setDialogState(() {
                          selectedInventoryItemRef = doc.reference;
                          final data = doc.data() as Map<String, dynamic>?;
                          selectedUnitRef = data?['unit'] as DocumentReference?;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<String>(
                    title: const Text('Quantified'),
                    subtitle: const Text('Specific amount (e.g., 100g)'),
                    value: 'quantified',
                    groupValue: ingredientType,
                    onChanged: (v) =>
                        setDialogState(() => ingredientType = v ?? 'quantified'),
                  ),
                  RadioListTile<String>(
                    title: const Text('On-Hand'),
                    subtitle: const Text('No specific amount needed'),
                    value: 'on-hand',
                    groupValue: ingredientType,
                    onChanged: (v) =>
                        setDialogState(() => ingredientType = v ?? 'on-hand'),
                  ),
                  if (ingredientType == 'quantified') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                          labelText: "Quantity", border: OutlineInputBorder()),
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('units')
                          .orderBy('name')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final items = snapshot.data!.docs
                            .map((doc) => DropdownMenuItem<DocumentReference>(
                            value: doc.reference,
                            child: Text((doc.data()
                            as Map<String, dynamic>)['name'])))
                            .toList();
                        return DropdownButtonFormField<DocumentReference>(
                          value: selectedUnitRef,
                          hint: const Text("Select Unit"),
                          items: items,
                          onChanged: (ref) =>
                              setDialogState(() => selectedUnitRef = ref),
                          decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                        );
                      },
                    ),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel")),
              ElevatedButton(
                child: const Text("Save"),
                onPressed: () {
                  if (selectedInventoryItemRef == null) return;
                  Navigator.of(context).pop({
                    'inventoryItemRef': selectedInventoryItemRef,
                    'quantity': ingredientType == 'quantified'
                        ? num.tryParse(quantityController.text) ?? 0
                        : null,
                    'unitRef':
                    ingredientType == 'quantified' ? selectedUnitRef : null,
                    'type': ingredientType,
                  });
                },
              ),
            ],
          );
        });
      },
    );

    if (result != null && mounted) {
      setState(() {
        if (isEditingIngredient) {
          _ingredients[editIndex!] = result;
        } else {
          _ingredients.add(result);
        }
      });
    }
  }

  Future<void> _showPrepTaskDialog({int? index}) async {
    final taskToEdit = (index != null) ? _prepTasks[index] : null;
    final taskController =
    TextEditingController(text: taskToEdit?['taskName'] ?? '');
    DocumentReference? linkedDishRef = taskToEdit?['linkedDishRef'];

    DocumentSnapshot? initialComponentDoc;
    if (linkedDishRef != null) {
      initialComponentDoc = await linkedDishRef.get();
    }

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(taskToEdit == null ? "Add Prep Step" : "Edit Prep Step"),
        content: StatefulBuilder(builder: (context, setDialogState) {
          return SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                      controller: taskController,
                      decoration: const InputDecoration(labelText: "Step Name"),
                      autofocus: true),
                  const SizedBox(height: 24),
                  const Text("Link to a Component (Optional)"),
                  const SizedBox(height: 8),
                  DropdownSearch<DocumentSnapshot>(
                    asyncItems: (String? filter) => FirebaseFirestore.instance
                        .collection('dishes').where('isComponent', isEqualTo: true).orderBy('dishName').get()
                        .then((snapshot) => snapshot.docs),
                    itemAsString: (DocumentSnapshot doc) => (doc.data() as Map<String, dynamic>)['dishName'] as String,
                    selectedItem: initialComponentDoc,
                    popupProps: const PopupProps.menu(showSearchBox: true),
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(labelText: "Select Component", border: OutlineInputBorder()),
                    ),
                    onChanged: (doc) =>
                        setDialogState(() => linkedDishRef = doc?.reference),
                    clearButtonProps: const ClearButtonProps(isVisible: true),
                  ),
                ]),
          );
        }),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (taskController.text.trim().isNotEmpty) {
                Navigator.of(context).pop({
                  'taskName': taskController.text.trim(),
                  'linkedDishRef': linkedDishRef
                });
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

    final dishData = {
      'dishName': _nameController.text.trim(),
      'category': _categoryController.text.trim(),
      'recipeInstructions': _recipeInstructionsController.text.trim(),
      'isActive': _isActive,
      'isComponent': _isComponent,
      'lastUpdated': FieldValue.serverTimestamp()
    };
    try {
      DocumentReference dishRef;
      if (_isEditing) {
        dishRef = widget.dishDocument!.reference;
        await dishRef.update(dishData);
      } else {
        dishRef =
        await FirebaseFirestore.instance.collection('dishes').add(dishData);
      }

      final batch = FirebaseFirestore.instance.batch();

      final oldIngredients = await dishRef.collection('ingredients').get();
      for (final doc in oldIngredients.docs) {
        batch.delete(doc.reference);
      }
      for (final ingredient in _ingredients) {
        final ingredientRef = dishRef.collection('ingredients').doc();
        batch.set(ingredientRef, {
          'inventoryItemRef': ingredient['inventoryItemRef'],
          'quantity': ingredient['quantity'],
          'unitId': ingredient['unitRef'],
          'type': ingredient['type']
        });
      }

      final oldPrepTasks = await dishRef.collection('prepTasks').get();
      for (final doc in oldPrepTasks.docs) {
        batch.delete(doc.reference);
      }
      for (final task in _prepTasks) {
        final taskRef = dishRef.collection('prepTasks').doc();
        batch.set(taskRef, {
          'taskName': task['taskName'],
          'linkedDishRef': task['linkedDishRef'],
          'order': task['order']
        });
      }

      await batch.commit();

      if (!navigator.mounted) return;
      scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text("Saved successfully!"), backgroundColor: Colors.green));
      navigator.pop();

    } catch(e) {
      if(mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text("Failed to save: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if(mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _recipeInstructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Edit' : 'Create New'),
          actions: [
            IconButton(
                onPressed: _isLoading ? null : _saveDish,
                icon: const Icon(Icons.save),
                tooltip: "Save")
          ]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                      labelText: _isComponent
                          ? "Component Name"
                          : "Dish Name"),
                  validator: (v) => (v == null || v.isEmpty)
                      ? "Please enter a name"
                      : null),
              const SizedBox(height: 16),
              if (!_isComponent)
                TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                        labelText: "Category (e.g., Antipasti)")),
              const SizedBox(height: 16),
              if (!_isComponent)
                SwitchListTile(
                  title: const Text("Is Active"),
                  subtitle:
                  const Text("Active dishes appear in standard lists."),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              const SizedBox(height: 24),
              _buildSectionHeader(
                  "Ingredients", () => _showIngredientDialog()),
              _ingredients.isEmpty
                  ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: Text("No ingredients added.")))
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ingredients.length,
                itemBuilder: (context, index) {
                  final ingredient = _ingredients[index];
                  final bool isOnHand =
                      ingredient['type'] == 'on-hand';
                  return ListTile(
                    leading: const Icon(Icons.lunch_dining_outlined),
                    title: FirestoreNameWidget(
                        collection: 'inventoryItems',
                        docId: (ingredient['inventoryItemRef']
                        as DocumentReference)
                            .id,
                        fieldName: 'itemName'),
                    subtitle: isOnHand
                        ? const Text("On-Hand Item",
                        style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.blue))
                        : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(ingredient['quantity']
                              .toString()),
                          const SizedBox(width: 4),
                          FirestoreNameWidget(
                              collection: 'units',
                              docId: (ingredient['unitRef']
                              as DocumentReference?)
                                  ?.id)
                        ]),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            icon:
                            const Icon(Icons.edit_outlined),
                            onPressed: () =>
                                _showIngredientDialog(
                                    editIndex: index)),
                        IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => setState(
                                    () => _ingredients.removeAt(index))),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              if (!_isComponent) ...[
                _buildSectionHeader(
                    "Prep Steps", () => _showPrepTaskDialog()),
                if (_prepTasks.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                          child:
                          Text("No steps or components added.")))
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _prepTasks.length,
                    itemBuilder: (context, index) {
                      final task = _prepTasks[index];
                      return Card(
                        key: ValueKey(task['id'] ?? task['taskName']),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.drag_handle),
                          title: Text(task['taskName'] ?? ''),
                          subtitle: task['linkedDishRef'] != null
                              ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.link, size: 12),
                                const SizedBox(width: 4),
                                FirestoreNameWidget(
                                    collection: 'dishes',
                                    docId:
                                    (task['linkedDishRef']
                                    as DocumentReference)
                                        .id,
                                    fieldName: 'dishName',
                                    defaultText: "Linked Recipe")
                              ])
                              : null,
                          trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    icon: const Icon(
                                        Icons.edit_outlined),
                                    onPressed: () =>
                                        _showPrepTaskDialog(
                                            index: index)),
                                IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red),
                                    onPressed: () => setState(() =>
                                        _prepTasks.removeAt(index))),
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
              const Text("Recipe Instructions",
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                  controller: _recipeInstructionsController,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "1. Combine all ingredients..."),
                  maxLines: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onAdd) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          ElevatedButton.icon(
            // FIX: Corrected typo 'on onPressed' to 'onPressed'
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text("Add"))
        ]);
  }
}
// lib/add_inventory_item_screen.dart
// REFACTORED: Updated to use the central InventoryItem model from the provider.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'models/models.dart'; // <-- ADDED IMPORT FOR OUR MODELS

class AddInventoryItemScreen extends ConsumerStatefulWidget {
  final String? documentId;
  const AddInventoryItemScreen({super.key, this.documentId});

  @override
  ConsumerState<AddInventoryItemScreen> createState() => _AddInventoryItemScreenState();
}

class _AddInventoryItemScreenState extends ConsumerState<AddInventoryItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _minStockController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedSupplierId;
  String? _selectedLocationId;
  String? _selectedUnitId;

  bool _isInitialized = false;

  @override
  void dispose() {
    _itemNameController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.documentId != null && widget.documentId!.isNotEmpty;
    final formState = ref.watch(itemFormControllerProvider);
    final formController = ref.read(itemFormControllerProvider.notifier);

    if (isEditing) {
      // UPDATED: The listener now correctly expects an InventoryItem.
      ref.listen<AsyncValue<InventoryItem?>>(inventoryItemProvider(widget.documentId!), (prev, next) {
        if (!_isInitialized && next.hasValue && next.value != null) {
          final item = next.value!; // We know item is not null here.

          // UPDATED: Logic is now cleaner, using the model's properties.
          _itemNameController.text = item.itemName;
          _minStockController.text = item.minStockLevel.toString();

          setState(() {
            _selectedCategoryId = item.category?.id;
            _selectedSupplierId = item.supplier?.id;
            _selectedLocationId = item.location?.id;
            _selectedUnitId = item.unit?.id;
          });

          // Update the controller with the specific state it manages.
          formController.updateIsButcherItem(item.isButcherItem);
          _isInitialized = true;
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Item' : 'Add New Item'),
        actions: [
          formState.isLoading
              ? const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white))
              : IconButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                final Map<String, dynamic> itemData = {
                  'itemName': _itemNameController.text,
                  'minStockLevel': num.tryParse(_minStockController.text) ?? 0,
                  'category': _selectedCategoryId != null ? ref.read(firestoreProvider).collection('categories').doc(_selectedCategoryId) : null,
                  'supplier': _selectedSupplierId != null ? ref.read(firestoreProvider).collection('suppliers').doc(_selectedSupplierId) : null,
                  'location': _selectedLocationId != null ? ref.read(firestoreProvider).collection('locations').doc(_selectedLocationId) : null,
                  'unit': _selectedUnitId != null ? ref.read(firestoreProvider).collection('units').doc(_selectedUnitId) : null,
                };

                final error = await formController.saveItem(
                    existingDocId: widget.documentId,
                    itemData: itemData
                );

                if (error == null) {
                  scaffoldMessenger.showSnackBar(SnackBar(content: Text('Item ${isEditing ? 'updated' : 'added'} successfully!')));
                  navigator.pop();
                } else {
                  scaffoldMessenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                }
              }
            },
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _itemNameController,
                decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()),
                validator: (value) => (value == null || value.isEmpty) ? 'Item name is required' : null,
              ),
              const SizedBox(height: 24),
              _buildDropdown('categories', 'Select Category', _selectedCategoryId, (val) => setState(() => _selectedCategoryId = val), isRequired: true),
              const SizedBox(height: 16),
              _buildDropdown('suppliers', 'Select Supplier', _selectedSupplierId, (val) => setState(() => _selectedSupplierId = val), isRequired: true),
              const SizedBox(height: 16),
              _buildDropdown('locations', 'Select Location', _selectedLocationId, (val) => setState(() => _selectedLocationId = val), isRequired: true),
              const SizedBox(height: 16),
              _buildDropdown('units', 'Select Unit', _selectedUnitId, (val) => setState(() => _selectedUnitId = val), isRequired: true),
              const SizedBox(height: 16),
              TextFormField(
                controller: _minStockController,
                decoration: const InputDecoration(labelText: 'Minimum Stock Level', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              ),
              const SizedBox(height: 16),
              const Divider(),
              SwitchListTile(
                title: const Text("Butcher Item"),
                subtitle: const Text("Can this item be requested by the butcher?"),
                value: formState.isButcherItem,
                onChanged: (value) {
                  formController.updateIsButcherItem(value);
                },
              ),
              const Divider(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String collection, String hint, String? value, Function(String?) onChanged, {bool isRequired = false}) {
    // This defines a local provider just for this dropdown widget.
    final dropdownStreamProvider = StreamProvider.autoDispose.family<QuerySnapshot, String>(
            (ref, collection) => ref.watch(firestoreProvider).collection(collection).orderBy('name').snapshots()
    );

    return Consumer(
      builder: (context, ref, child) {
        final asyncData = ref.watch(dropdownStreamProvider(collection));
        return asyncData.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text('Error loading $collection'),
          data: (snapshot) {
            final items = snapshot.docs.map((doc) {
              final docData = doc.data() as Map<String, dynamic>?;
              final name = docData?['name'] ?? 'Unnamed';
              return DropdownMenuItem<String>(value: doc.id, child: Text(name));
            }).toList();
            return DropdownButtonFormField<String>(
              value: value,
              hint: Text(hint),
              items: items,
              onChanged: onChanged,
              validator: (val) => (isRequired && val == null) ? 'This field is required' : null,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            );
          },
        );
      },
    );
  }
}
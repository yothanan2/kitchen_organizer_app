// lib/add_edit_inventory_item_screen.dart
// CORRECTED: Fixed the typo in the createState method.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'providers.dart'; // Ensure providers.dart is correctly imported

class AddEditInventoryItemScreen extends ConsumerStatefulWidget {
  final String? docId; // Null for add, has value for edit

  const AddEditInventoryItemScreen({super.key, this.docId});

  @override
  // THIS IS THE CORRECTED LINE
  ConsumerState<AddEditInventoryItemScreen> createState() => _AddEditInventoryItemState();
}

class _AddEditInventoryItemState extends ConsumerState<AddEditInventoryItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _quantityOnHandController = TextEditingController(); // For initial quantity for new items
  String? _selectedUnitId;
  String? _selectedCategoryId;
  String? _selectedSupplierId;
  String? _selectedLocationId;

  // Track if it's a butcher item
  bool _isButcherItem = false;

  @override
  void initState() {
    super.initState();
    if (widget.docId != null) {
      // If editing, load existing data
      _loadItemData();
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityOnHandController.dispose();
    super.dispose();
  }

  Future<void> _loadItemData() async {
    final item = await ref.read(inventoryItemProvider(widget.docId!).future);
    if (item != null && item.exists) {
      final data = item.data() as Map<String, dynamic>;
      _itemNameController.text = data['itemName'] ?? '';
      _quantityOnHandController.text = (data['quantityOnHand'] ?? 0).toString(); // Display current quantity
      _selectedUnitId = (data['unit'] as DocumentReference?)?.id;
      _selectedCategoryId = (data['category'] as DocumentReference?)?.id;
      _selectedSupplierId = (data['supplier'] as DocumentReference?)?.id;
      _selectedLocationId = (data['location'] as DocumentReference?)?.id;
      _isButcherItem = data['isButcherItem'] ?? false; // Load existing butcher item status

      // Set initial state for the StateNotifier (important if you have complex logic in controller)
      ref.read(itemFormControllerProvider.notifier).setInitialState(data);
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    final firestore = ref.read(firestoreProvider);
    final itemFormController = ref.read(itemFormControllerProvider.notifier);

    final itemData = {
      'itemName': _itemNameController.text.trim(),
      'unit': _selectedUnitId != null ? firestore.collection('units').doc(_selectedUnitId) : null,
      'category': _selectedCategoryId != null ? firestore.collection('categories').doc(_selectedCategoryId) : null,
      'supplier': _selectedSupplierId != null ? firestore.collection('suppliers').doc(_selectedSupplierId) : null,
      'location': _selectedLocationId != null ? firestore.collection('locations').doc(_selectedLocationId) : null,
    };

    if (widget.docId == null) {
      // For new items, add initial quantity
      itemData['quantityOnHand'] = num.tryParse(_quantityOnHandController.text) ?? 0;
    }

    final String? errorMessage = await itemFormController.saveItem(
      existingDocId: widget.docId,
      itemData: itemData,
    );

    if (mounted) {
      if (errorMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item ${widget.docId == null ? 'added' : 'updated'} successfully!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(); // Go back to inventory list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch relevant providers for dropdowns
    final unitsAsync = ref.watch(unitsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final suppliersAsync = ref.watch(suppliersStreamProvider);
    final locationsAsync = ref.watch(locationsStreamProvider);

    // Watch the form controller's state for loading and butcher item status
    final formState = ref.watch(itemFormControllerProvider);
    _isButcherItem = formState.isButcherItem; // Update local state based on controller

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.docId == null ? 'Add Inventory Item' : 'Edit Inventory Item'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _itemNameController,
                decoration: const InputDecoration(labelText: 'Item Name *', border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? 'Please enter an item name.' : null,
              ),
              const SizedBox(height: 16),
              if (widget.docId == null) // Only show quantity for new items
                TextFormField(
                  controller: _quantityOnHandController,
                  decoration: const InputDecoration(labelText: 'Initial Quantity on Hand', border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                  validator: (value) {
                    if (value == null || value.isEmpty) return null; // Optional field
                    if (num.tryParse(value) == null) return 'Please enter a valid number.';
                    return null;
                  },
                ),
              if (widget.docId == null) const SizedBox(height: 16),
              // Unit Dropdown
              _buildDropdown(
                label: 'Unit',
                value: _selectedUnitId,
                asyncData: unitsAsync,
                onChanged: (newValue) => setState(() => _selectedUnitId = newValue),
              ),
              const SizedBox(height: 16),
              // Category Dropdown
              _buildDropdown(
                label: 'Category',
                value: _selectedCategoryId,
                asyncData: categoriesAsync,
                onChanged: (newValue) => setState(() => _selectedCategoryId = newValue),
              ),
              const SizedBox(height: 16),
              // Supplier Dropdown
              _buildDropdown(
                label: 'Supplier',
                value: _selectedSupplierId,
                asyncData: suppliersAsync,
                onChanged: (newValue) => setState(() => _selectedSupplierId = newValue),
              ),
              const SizedBox(height: 16),
              // Location Dropdown
              _buildDropdown(
                label: 'Location',
                value: _selectedLocationId,
                asyncData: locationsAsync,
                onChanged: (newValue) => setState(() => _selectedLocationId = newValue),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isButcherItem,
                    onChanged: (newValue) {
                      setState(() {
                        _isButcherItem = newValue ?? false;
                      });
                      ref.read(itemFormControllerProvider.notifier).updateIsButcherItem(newValue ?? false);
                    },
                  ),
                  const Text('Flag as Butcher Item'),
                  Tooltip(
                    message: 'Items flagged as Butcher Items will appear on the butcher\'s requisition form.',
                    child: Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: formState.isLoading ? null : _saveItem,
                icon: formState.isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                label: Text(widget.docId == null ? 'Add Item' : 'Save Changes'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required AsyncValue<QuerySnapshot> asyncData,
    required ValueChanged<String?> onChanged,
  }) {
    return asyncData.when(
      data: (snapshot) {
        final items = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return DropdownMenuItem<String>(
            value: doc.id,
            child: Text(data['name'] ?? 'Unnamed'),
          );
        }).toList();

        return DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('None')), // Optional "None" option
            ...items,
          ],
          onChanged: onChanged,
        );
      },
      loading: () => DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: const [DropdownMenuItem(value: null, child: Text('Loading...'))],
        onChanged: null,
      ),
      error: (err, stack) => DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: const [DropdownMenuItem(value: null, child: Text('Error loading'))],
        onChanged: null,
      ),
    );
  }
}
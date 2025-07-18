// lib/add_inventory_item_screen.dart
// V3: Updated DropdownSearch to use searchFieldProps.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:kitchen_organizer_app/providers.dart';

class AddInventoryItemScreen extends ConsumerStatefulWidget {
  final String? documentId;
  const AddInventoryItemScreen({super.key, this.documentId});

  @override
  ConsumerState<AddInventoryItemScreen> createState() =>
      _AddInventoryItemScreenState();
}

class _AddInventoryItemScreenState
    extends ConsumerState<AddInventoryItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _itemCodeController = TextEditingController();
  final _parLevelController = TextEditingController();
  final _minStockController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedSupplierId;
  String? _selectedUnitId;
  String? _selectedLocationId;

  @override
  void initState() {
    super.initState();
    if (widget.documentId != null) {
      _loadItemData();
    }
  }

  void _loadItemData() {
    ref
        .read(inventoryItemProvider(widget.documentId!).future)
        .then((item) {
      if (item != null && mounted) {
        _nameController.text = item.itemName;
        _itemCodeController.text = item.itemCode ?? '';
        _parLevelController.text = item.parLevel.toString();
        _minStockController.text = item.minStockLevel.toString();
        setState(() {
          _selectedCategoryId = item.category?.id;
          _selectedSupplierId = item.supplier?.id;
          _selectedUnitId = item.unit?.id;
          _selectedLocationId = item.location?.id;
        });
        ref
            .read(itemFormControllerProvider.notifier)
            .updateIsButcherItem(item.isButcherItem);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _itemCodeController.dispose();
    _parLevelController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      final firestore = ref.read(firestoreProvider);
      final isButcherItem = ref.read(itemFormControllerProvider).isButcherItem;

      final itemData = {
        'itemName': _nameController.text,
        'itemCode': _itemCodeController.text,
        'category': _selectedCategoryId != null
            ? firestore.collection('categories').doc(_selectedCategoryId)
            : null,
        'supplier': _selectedSupplierId != null
            ? firestore.collection('suppliers').doc(_selectedSupplierId)
            : null,
        'unit': _selectedUnitId != null
            ? firestore.collection('units').doc(_selectedUnitId)
            : null,
        'location': _selectedLocationId != null
            ? firestore.collection('locations').doc(_selectedLocationId)
            : null,
        'parLevel': num.tryParse(_parLevelController.text) ?? 0,
        'minStockLevel': num.tryParse(_minStockController.text) ?? 0,
        'isButcherItem': isButcherItem,
      };

      final error = await ref
          .read(itemFormControllerProvider.notifier)
          .saveItem(existingDocId: widget.documentId, itemData: itemData);

      if (mounted) {
        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Item saved successfully!'),
                backgroundColor: Colors.green),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $error'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(itemFormControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.documentId == null ? 'Add Item' : 'Edit Item'),
        actions: [
          if (formState.isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: Colors.white),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveItem,
              tooltip: 'Save Item',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _itemCodeController,
                decoration: const InputDecoration(
                  labelText: 'Item Code (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              _buildDropdownSearch(
                label: 'Category',
                provider: categoriesStreamProvider,
                selectedId: _selectedCategoryId,
                onChanged: (id) => setState(() => _selectedCategoryId = id),
              ),
              const SizedBox(height: 16),
              _buildDropdownSearch(
                label: 'Supplier',
                provider: suppliersStreamProvider,
                selectedId: _selectedSupplierId,
                onChanged: (id) => setState(() => _selectedSupplierId = id),
              ),
              const SizedBox(height: 16),
              _buildDropdownSearch(
                label: 'Unit',
                provider: unitsStreamProvider,
                selectedId: _selectedUnitId,
                onChanged: (id) => setState(() => _selectedUnitId = id),
                isRequired: true,
              ),
              const SizedBox(height: 16),
              _buildDropdownSearch(
                label: 'Storage Location',
                provider: locationsStreamProvider,
                selectedId: _selectedLocationId,
                onChanged: (id) => setState(() => _selectedLocationId = id),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _parLevelController,
                      decoration: const InputDecoration(
                        labelText: 'Par Level',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _minStockController,
                      decoration: const InputDecoration(
                        labelText: 'Min Stock',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Butcher Item'),
                subtitle: const Text(
                    'Enable this if the item is for butcher requisitions.'),
                value: formState.isButcherItem,
                onChanged: (value) {
                  ref
                      .read(itemFormControllerProvider.notifier)
                      .updateIsButcherItem(value);
                },
                secondary: const Icon(Icons.kitchen),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownSearch({
    required String label,
    required AutoDisposeStreamProvider<QuerySnapshot<Object?>> provider,
    required String? selectedId,
    required ValueChanged<String?> onChanged,
    bool isRequired = false,
  }) {
    final asyncData = ref.watch(provider);

    return asyncData.when(
      loading: () => const LinearProgressIndicator(),
      error: (err, stack) => Text('Error loading $label: $err'),
      data: (snapshot) {
        final items = snapshot.docs
            .map((doc) =>
        {'id': doc.id, 'name': (doc.data() as Map)['name'] ?? ''})
            .toList();

        final selectedItem = items.firstWhere(
              (item) => item['id'] == selectedId,
          orElse: () => {'id': null, 'name': null},
        );

        return DropdownSearch<Map<String, dynamic>>(
          items: items,
          itemAsString: (item) => item['name'] as String,
          selectedItem: selectedItem['id'] != null ? selectedItem : null,
          onChanged: (item) => onChanged(item?['id'] as String?),
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
          ),
          popupProps: const PopupProps.menu(
            showSearchBox: true,
            // CORRECTED: This now uses the correct property.
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: 'Search...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          validator: (value) {
            if (isRequired && value == null) {
              return 'Please select a $label';
            }
            return null;
          },
        );
      },
    );
  }
}
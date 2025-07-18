// lib/shopping_list_screen.dart
// CORRECTED: Removed the duplicate widget definition and imported the central one.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchen_organizer_app/screens/admin/confirm_order_screen.dart';
import 'package:kitchen_organizer_app/widgets/firestore_name_widget.dart'; // <-- IMPORT a single source of truth

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  Map<String, List<Map<String, dynamic>>>? _orderList;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialSuggestions();
  }

  Future<void> _loadInitialSuggestions() async {
    setState(() { _isLoading = true; });
    final inventorySnapshot = await FirebaseFirestore.instance.collection('inventoryItems').get();
    final itemsToReorder = <String, List<Map<String, dynamic>>>{};

    for (var doc in inventorySnapshot.docs) {
      final data = doc.data();
      final num quantity = data['quantityOnHand'] ?? 0;
      final num minStock = data['minStockLevel'] ?? 0;

      if (quantity <= minStock) {
        final supplierRef = data['supplier'] as DocumentReference?;
        final key = supplierRef?.id ?? 'unassigned';
        if (!itemsToReorder.containsKey(key)) {
          itemsToReorder[key] = [];
        }
        itemsToReorder[key]!.add({
          'isCustom': false,
          'inventoryItemId': doc.id,
          'itemName': data['itemName'] ?? 'No Name',
          'quantity': (data['minStockLevel'] ?? 0) - (data['quantityOnHand'] ?? 0),
          'unitId': (data['unit'] as DocumentReference?)?.id,
        });
      }
    }
    setState(() {
      _orderList = itemsToReorder;
      _isLoading = false;
    });
  }

  void _removeItem(String supplierId, int itemIndex) {
    setState(() {
      _orderList![supplierId]?.removeAt(itemIndex);
      if (_orderList![supplierId]?.isEmpty ?? false) {
        _orderList!.remove(supplierId);
      }
    });
  }

  Future<void> _editItem(String supplierId, int itemIndex) async {
    final itemToEdit = _orderList![supplierId]![itemIndex];
    final quantityController = TextEditingController(text: itemToEdit['quantity'].toString());
    String? selectedUnitId = itemToEdit['unitId'];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Edit: ${itemToEdit['itemName']}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: quantityController, decoration: const InputDecoration(labelText: "Quantity"), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('units').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final unitItems = snapshot.data!.docs.map((doc) => DropdownMenuItem<String>(value: doc.id, child: Text((doc.data() as Map<String, dynamic>)['name']))).toList();
                  final unitExists = unitItems.any((item) => item.value == selectedUnitId);
                  return DropdownButtonFormField<String>(
                    value: unitExists ? selectedUnitId : null,
                    hint: const Text("Select Unit"),
                    items: unitItems,
                    onChanged: (newValue) => setDialogState(() => selectedUnitId = newValue),
                  );
                },
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop({'quantity': num.tryParse(quantityController.text) ?? 0, 'unitId': selectedUnitId}),
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _orderList![supplierId]![itemIndex]['quantity'] = result['quantity'];
        _orderList![supplierId]![itemIndex]['unitId'] = result['unitId'];
      });
    }
  }

  Future<void> _addItem(String supplierId) async {
    String? selectedInventoryItemId;
    String? selectedUnitId;
    final quantityController = TextEditingController();
    final customItemController = TextEditingController();
    bool isCustom = false;

    final newItem = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Add Item to Order"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isCustom)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('inventoryItems').orderBy('itemName').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      final items = snapshot.data!.docs.map((doc) => DropdownMenuItem<String>(value: doc.id, child: Text((doc.data() as Map<String, dynamic>)['itemName']))).toList();
                      return DropdownButtonFormField<String>(
                        value: selectedInventoryItemId,
                        hint: const Text("Select Inventory Item"),
                        items: items,
                        onChanged: (newValue) => setDialogState(() => selectedInventoryItemId = newValue),
                      );
                    },
                  ),
                CheckboxListTile(
                  title: const Text("Add a special/custom item?"),
                  value: isCustom,
                  onChanged: (newValue) => setDialogState(() => isCustom = newValue ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (isCustom)
                  TextField(controller: customItemController, decoration: const InputDecoration(labelText: "Custom Item Name")),
                const SizedBox(height: 16),
                TextField(controller: quantityController, decoration: const InputDecoration(labelText: "Quantity"), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('units').orderBy('name').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final unitItems = snapshot.data!.docs.map((doc) => DropdownMenuItem<String>(value: doc.id, child: Text((doc.data() as Map<String, dynamic>)['name']))).toList();
                    return DropdownButtonFormField<String>(
                      value: selectedUnitId,
                      hint: const Text("Select Unit"),
                      items: unitItems,
                      onChanged: (newValue) => setDialogState(() => selectedUnitId = newValue),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final itemName = isCustom
                    ? customItemController.text.trim()
                    : await FirebaseFirestore.instance.collection('inventoryItems').doc(selectedInventoryItemId).get().then((doc) => (doc.data() as Map<String, dynamic>)['itemName']);
                final newItemData = {
                  'isCustom': isCustom,
                  'itemName': itemName,
                  'inventoryItemId': selectedInventoryItemId,
                  'quantity': num.tryParse(quantityController.text) ?? 0,
                  'unitId': selectedUnitId,
                };

                if ((isCustom && customItemController.text.trim() == '') || (!isCustom && selectedInventoryItemId == null) || newItemData['quantity'] == 0 || selectedUnitId == null) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields correctly.")));
                  return;
                }
                Navigator.of(context).pop(newItemData);
              },
              child: const Text("Add Item"),
            ),
          ],
        ),
      ),
    );

    if (newItem != null) {
      setState(() {
        if (!_orderList!.containsKey(supplierId)) {
          _orderList![supplierId] = [];
        }
        _orderList![supplierId]!.add(newItem);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Worksheet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialSuggestions,
            tooltip: 'Reset to Suggestions',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_orderList == null || _orderList!.isEmpty)
          ? const Center(child: Text('No items need ordering. Add some manually!', style: TextStyle(fontSize: 18)))
          : ListView(
        children: _orderList!.keys.map((supplierId) {
          final items = _orderList![supplierId]!;
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: ExpansionTile(
              title: Row(
                children: [
                  Expanded(child: FirestoreNameWidget(
                    docRef: supplierId != 'unassigned' ? FirebaseFirestore.instance.collection('suppliers').doc(supplierId) : null,
                    builder: (context, name) => Text(
                      name.isEmpty ? 'Unassigned Supplier' : name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
                    ),
                  )),
                  IconButton(
                    icon: const Icon(Icons.email_outlined, color: Colors.blue),
                    onPressed: (supplierId == 'unassigned' || items.isEmpty)
                        ? null
                        : () async {
                      final result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (context) => ConfirmOrderScreen(
                            supplierId: supplierId,
                            items: items,
                          ),
                        ),
                      );
                      if (result == true) {
                        _loadInitialSuggestions();
                      }
                    },
                    tooltip: 'Proceed to Order Confirmation',
                  ),
                ],
              ),
              subtitle: Text('${items.length} item(s)'),
              children: [
                ...items.asMap().entries.map((entry) {
                  int itemIndex = entry.key;
                  Map<String, dynamic> item = entry.value;
                  return ListTile(
                    leading: item['isCustom'] == true ? const Icon(Icons.star, color: Colors.amber) : null,
                    title: Text(item['itemName'], style: TextStyle(fontStyle: item['isCustom'] ? FontStyle.italic : FontStyle.normal)),
                    subtitle: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item['quantity'].toString()),
                        const SizedBox(width: 4),
                        FirestoreNameWidget(
                          docRef: item['unitId'] != null ? FirebaseFirestore.instance.collection('units').doc(item['unitId']) : null,
                          builder: (context, name) => Text(name),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editItem(supplierId, itemIndex)),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removeItem(supplierId, itemIndex)),
                      ],
                    ),
                  );
                }).toList(),
                Padding(
                  padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text("Add Item"),
                      onPressed: () => _addItem(supplierId),
                    ),
                  ),
                )
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
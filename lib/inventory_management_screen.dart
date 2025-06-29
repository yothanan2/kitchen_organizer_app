// lib/inventory_management_screen.dart
// UPDATED: Now navigates to the official AddInventoryItemScreen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'providers.dart';
import 'add_inventory_item_screen.dart'; // <-- CORRECTED IMPORT
import 'models/models.dart';

// Provider to fetch all inventory items using the central model.
final allInventoryItemsProvider = StreamProvider.autoDispose<List<InventoryItem>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('inventoryItems').snapshots().map((snapshot) {
    return snapshot.docs.map((doc) => InventoryItem.fromFirestore(doc.data(), doc.id)).toList();
  });
});


class InventoryManagementScreen extends ConsumerStatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  ConsumerState<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends ConsumerState<InventoryManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<InventoryItem> _filteredItems = [];
  String _sortColumn = 'itemName';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    final allItems = ref.read(allInventoryItemsProvider).value ?? [];
    setState(() {
      _filteredItems = allItems.where((item) => item.itemName.toLowerCase().contains(query)).toList();
      _sortItems();
    });
  }

  void _sortItems() {
    setState(() {
      _filteredItems.sort((a, b) {
        dynamic valA;
        dynamic valB;

        switch (_sortColumn) {
          case 'itemName':
            valA = a.itemName.toLowerCase();
            valB = b.itemName.toLowerCase();
            break;
          case 'quantityOnHand':
            valA = a.quantityOnHand;
            valB = b.quantityOnHand;
            break;
          case 'lastUpdated':
            valA = a.lastUpdated?.toDate().millisecondsSinceEpoch ?? 0;
            valB = b.lastUpdated?.toDate().millisecondsSinceEpoch ?? 0;
            break;
          default:
            valA = a.itemName.toLowerCase();
            valB = b.itemName.toLowerCase();
        }

        int comparison = Comparable.compare(valA, valB);
        return _sortAscending ? comparison : -comparison;
      });
    });
  }

  Future<void> _deleteItem(String itemId) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this inventory item? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ) ?? false;

    if (!confirm) return;

    final firestore = ref.read(firestoreProvider);
    try {
      await firestore.collection('inventoryItems').doc(itemId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting item: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _navigateToEditItem(String? docId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        // CORRECTED: Navigates to the screen we decided to keep.
        builder: (context) => AddInventoryItemScreen(documentId: docId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncInventoryItems = ref.watch(allInventoryItemsProvider);
    final unitsMapAsync = ref.watch(unitsMapProvider);
    final categoriesMapAsync = ref.watch(categoriesMapProvider);
    final suppliersMapAsync = ref.watch(suppliersMapProvider);
    final locationsMapAsync = ref.watch(locationsMapProvider);


    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToEditItem(null),
            tooltip: 'Add New Item',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Items',
                hintText: 'Enter item name',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
          ),
          asyncInventoryItems.when(
            loading: () => const LinearProgressIndicator(),
            error: (err, stack) => Center(child: Text('Error loading inventory: $err')),
            data: (items) {
              if (_searchController.text.isEmpty && _filteredItems.isEmpty) {
                _filteredItems = items;
                _sortItems();
              } else if (_searchController.text.isNotEmpty) {
                _filterItems();
              } else {
                final currentFilteredIds = _filteredItems.map((e) => e.id).toSet();
                final newItemsIds = items.map((e) => e.id).toSet();
                if (currentFilteredIds.length != newItemsIds.length || !currentFilteredIds.containsAll(newItemsIds)) {
                  _filteredItems = items;
                  _sortItems();
                }
              }

              if (_filteredItems.isEmpty) {
                return const Expanded(
                  child: Center(
                    child: Text(
                      'No inventory items found. Add new items using the "+" button.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                );
              }

              return Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    columnSpacing: 12,
                    horizontalMargin: 12,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 60,
                    columns: [
                      DataColumn(
                        label: const Text('Item Name'),
                        onSort: (columnIndex, ascending) {
                          setState(() {
                            _sortColumn = 'itemName';
                            _sortAscending = ascending;
                            _sortItems();
                          });
                        },
                      ),
                      DataColumn(
                        label: const Text('Qty'),
                        numeric: true,
                        onSort: (columnIndex, ascending) {
                          setState(() {
                            _sortColumn = 'quantityOnHand';
                            _sortAscending = ascending;
                            _sortItems();
                          });
                        },
                      ),
                      const DataColumn(label: Text('Unit')),
                      const DataColumn(label: Text('Category')),
                      const DataColumn(label: Text('Location')),
                      DataColumn(
                        label: const Text('Last Updated'),
                        onSort: (columnIndex, ascending) {
                          setState(() {
                            _sortColumn = 'lastUpdated';
                            _sortAscending = ascending;
                            _sortItems();
                          });
                        },
                      ),
                      const DataColumn(label: Text('Actions')),
                    ],
                    rows: _filteredItems.map((item) {
                      final unitsMap = unitsMapAsync.value ?? {};
                      final categoriesMap = categoriesMapAsync.value ?? {};
                      final locationsMap = locationsMapAsync.value ?? {};

                      final unitName = unitsMap[item.unit?.id] ?? 'N/A';
                      final categoryName = categoriesMap[item.category?.id] ?? 'N/A';
                      final locationName = locationsMap[item.location?.id] ?? 'N/A';
                      final lastUpdatedDate = item.lastUpdated?.toDate();
                      final formattedDate = lastUpdatedDate != null ? DateFormat('MMM d, yy HH:mm').format(lastUpdatedDate) : 'N/A';

                      return DataRow(
                        cells: [
                          DataCell(Text(item.itemName)),
                          DataCell(Text(item.quantityOnHand.toString())),
                          DataCell(Text(unitName)),
                          DataCell(Text(categoryName)),
                          DataCell(Text(locationName)),
                          DataCell(Text(formattedDate)),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _navigateToEditItem(item.id),
                                tooltip: 'Edit Item',
                                color: Colors.blue,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteItem(item.id),
                                tooltip: 'Delete Item',
                                color: Colors.red,
                              ),
                            ],
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
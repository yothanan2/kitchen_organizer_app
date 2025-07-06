// lib/inventory_overview_screen.dart
// CORRECTED: Removed the duplicate widget definition and imported the central one.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchen_organizer_app/screens/admin/add_inventory_item_screen.dart';
import 'package:kitchen_organizer_app/screens/admin/units_screen.dart';
import 'package:kitchen_organizer_app/screens/admin/suppliers_screen.dart';
import 'package:kitchen_organizer_app/screens/admin/locations_screen.dart';
import 'package:kitchen_organizer_app/screens/admin/categories_screen.dart';
import 'package:kitchen_organizer_app/providers.dart';
import 'package:kitchen_organizer_app/widgets/firestore_name_widget.dart'; // <-- IMPORT a single source of truth

class InventoryOverviewScreen extends ConsumerWidget {
  const InventoryOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(allSuppliersProvider);
    return suppliersAsync.when(
      loading: () => Scaffold(appBar: AppBar(title: const Text('Inventory Overview')), body: const Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(appBar: AppBar(title: const Text('Error')), body: Center(child: Text('$err'))),
      data: (suppliers) {
        if (suppliers.isEmpty) {
          return Scaffold(appBar: AppBar(title: const Text('Inventory Overview')), body: const Center(child: Text("No suppliers found.")),
            floatingActionButton: FloatingActionButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddInventoryItemScreen())),
              tooltip: 'Add Item',
              child: const Icon(Icons.add),
            ),
          );
        }
        return DefaultTabController(
          length: suppliers.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Inventory Overview'),
              actions: [
                IconButton(icon: const Icon(Icons.category_outlined), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CategoriesScreen())), tooltip: 'Manage Categories'),
                IconButton(icon: const Icon(Icons.square_foot_outlined), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const UnitsScreen())), tooltip: 'Manage Units'),
                IconButton(icon: const Icon(Icons.local_shipping_outlined), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SuppliersScreen())), tooltip: 'Manage Suppliers'),
                IconButton(icon: const Icon(Icons.location_on_outlined), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LocationsScreen())), tooltip: 'Manage Locations'),
              ],
              bottom: TabBar(isScrollable: true, tabs: suppliers.map((doc) => Tab(text: (doc.data() as Map<String, dynamic>)['name'])).toList()),
            ),
            body: TabBarView(children: suppliers.map((doc) => _InventoryFilteredList(supplierId: doc.id)).toList()),
            floatingActionButton: FloatingActionButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddInventoryItemScreen())),
              tooltip: 'Add Item',
              child: const Icon(Icons.add),
            ),
          ),
        );
      },
    );
  }
}

class _InventoryFilteredList extends ConsumerWidget {
  final String supplierId;
  const _InventoryFilteredList({required this.supplierId});

  Future<void> _showDeleteConfirmation(BuildContext context, DocumentReference itemRef, String itemName) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete the item "$itemName"?'),
                const Text('This action cannot be undone.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () async {
                await itemRef.delete();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(itemsBySupplierProvider(supplierId));
    final locationsAsync = ref.watch(locationsMapProvider);
    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text("Error: $err")),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No items found for this supplier.'));
        }
        return locationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text("Error loading locations: $err")),
            data: (locationsMap) {
              final locationDropdownItems = locationsMap.entries.map((entry) {
                return DropdownMenuItem<String>(value: entry.key, child: Text(entry.value));
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final document = items[index];
                  final data = document.data() as Map<String, dynamic>;
                  final bool isLowStock = (data['quantityOnHand'] ?? 0) <= (data['minStockLevel'] ?? 0);
                  final currentLocationId = (data['location'] as DocumentReference?)?.id;
                  final itemName = data['itemName'] ?? 'Unnamed Item';

                  return Card(
                    color: isLowStock ? Colors.red.shade100 : null,
                    child: ListTile(
                      title: Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: DropdownButton<String>(
                                  value: currentLocationId,
                                  hint: const Text("Assign Location"),
                                  items: locationDropdownItems,
                                  onChanged: (newLocationId) async {
                                    if (newLocationId != null) {
                                      final itemRef = document.reference;
                                      final newLocationRef = FirebaseFirestore.instance.collection('locations').doc(newLocationId);
                                      await itemRef.update({'location': newLocationRef});
                                    }
                                  },
                                  isDense: true,
                                  underline: const SizedBox.shrink(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.category_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              FirestoreNameWidget(collection: 'categories', docId: data['category']),
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FirestoreNameWidget(collection: 'units', docId: data['unit']),
                            const SizedBox(width: 8),
                            Text('${data['quantityOnHand'] ?? 0}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isLowStock ? Colors.red.shade900 : Colors.black)),
                            IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit Item',
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => AddInventoryItemScreen(documentId: document.id)))
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Delete Item',
                              onPressed: () => _showDeleteConfirmation(context, document.reference, itemName),
                            ),
                          ]
                      ),
                    ),
                  );
                },
              );
            }
        );
      },
    );
  }
}
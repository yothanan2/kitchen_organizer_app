// lib/screens/admin/manage_butcher_list_screen.dart
// FIXED: Added equality checks to ButcherListItem to fix editing bug.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';

// A simple data class to hold our combined item data
class ButcherListItem {
  final String name;
  final String source;
  ButcherListItem({required this.name, required this.source});

  // --- FIX: Added equality operator and hashCode for proper object comparison ---
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ButcherListItem &&
              runtimeType == other.runtimeType &&
              name == other.name &&
              source == other.source;

  @override
  int get hashCode => name.hashCode ^ source.hashCode;
}

class ManageButcherListScreen extends ConsumerStatefulWidget {
  const ManageButcherListScreen({super.key});

  @override
  ConsumerState<ManageButcherListScreen> createState() =>
      _ManageButcherListScreenState();
}

class _ManageButcherListScreenState extends ConsumerState<ManageButcherListScreen> {

  void _showItemDialog(BuildContext context, {DocumentSnapshot? document, int currentItemCount = 0}) {
    ButcherListItem? selectedItem;
    List<String> selectedUnitIds = [];
    final bool isEditing = document != null;

    if (isEditing) {
      final data = document!.data() as Map<String, dynamic>?;
      if (data != null) {
        selectedItem = ButcherListItem(name: data['name'] ?? '', source: 'Pre-selected');
        if (data['allowedUnitRefs'] != null) {
          selectedUnitIds = (data['allowedUnitRefs'] as List)
              .map((ref) => (ref as DocumentReference).id)
              .toList();
        }
      }
    }

    Future<List<ButcherListItem>> getData(String? filter) async {
      final firestore = FirebaseFirestore.instance;
      final inventoryFuture = firestore.collection('inventoryItems').get();
      final dishesFuture = firestore.collection('dishes').get();

      final results = await Future.wait([inventoryFuture, dishesFuture]);
      final inventorySnapshot = results[0];
      final dishesSnapshot = results[1];

      final List<ButcherListItem> combinedList = [];

      for (var doc in inventorySnapshot.docs) {
        final data = doc.data();
        combinedList.add(ButcherListItem(
          name: data['itemName'] ?? 'Unnamed Inventory Item',
          source: 'Inventory',
        ));
      }

      for (var doc in dishesSnapshot.docs) {
        final data = doc.data();
        combinedList.add(ButcherListItem(
          name: data['dishName'] ?? 'Unnamed Dish',
          source: data['isComponent'] == true ? 'Component' : 'Dish',
        ));
      }

      combinedList.sort((a, b) => a.name.compareTo(b.name));
      return combinedList;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Item' : 'Add Item to Butcher List'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownSearch<ButcherListItem>(
                        asyncItems: getData,
                        enabled: !isEditing,
                        itemAsString: (item) => item.name,
                        selectedItem: selectedItem,
                        onChanged: (item) {
                          setDialogState(() {
                            selectedItem = item;
                          });
                        },
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: const TextFieldProps(
                            decoration: InputDecoration(labelText: "Search...", border: OutlineInputBorder()),
                          ),
                          itemBuilder: (context, item, isSelected) {
                            return ListTile(title: Text(item.name), subtitle: Text(item.source));
                          },
                        ),
                        dropdownDecoratorProps: const DropDownDecoratorProps(
                          dropdownSearchDecoration: InputDecoration(labelText: "Select an Item", border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Consumer(
                        builder: (context, ref, child) {
                          final unitsAsync = ref.watch(unitsStreamProvider);
                          return unitsAsync.when(
                            loading: () => const CircularProgressIndicator(),
                            error: (e, s) => const Text("Could not load units."),
                            data: (unitsSnapshot) {
                              final allUnits = unitsSnapshot.docs;
                              final initialSelectedNames = selectedUnitIds.map((id) {
                                try {
                                  final doc = allUnits.firstWhere((doc) => doc.id == id);
                                  return (doc.data() as Map<String, dynamic>)['name'] as String;
                                } catch (e) {
                                  return '';
                                }
                              }).where((name) => name.isNotEmpty).toList();

                              return DropdownSearch<String>.multiSelection(
                                items: allUnits.map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String).toList(),
                                selectedItems: initialSelectedNames,
                                popupProps: PopupPropsMultiSelection.menu(
                                  showSearchBox: true,
                                  itemBuilder: (context, item, isSelected) => ListTile(title: Text(item)),
                                ),
                                dropdownDecoratorProps: const DropDownDecoratorProps(
                                  dropdownSearchDecoration: InputDecoration(
                                    labelText: "Allowed Units",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                onChanged: (List<String> selectedNames) {
                                  setDialogState(() {
                                    selectedUnitIds = selectedNames.map((name) {
                                      return allUnits.firstWhere((doc) => (doc.data() as Map<String, dynamic>)['name'] == name).id;
                                    }).toList();
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedItem != null && selectedUnitIds.isNotEmpty) {
                      final firestore = FirebaseFirestore.instance;
                      final collection = firestore.collection('butcher_request_items');
                      final List<DocumentReference> unitRefs = selectedUnitIds
                          .map((id) => firestore.collection('units').doc(id))
                          .toList();

                      final dataToSave = {
                        'name': selectedItem!.name,
                        'allowedUnitRefs': unitRefs,
                      };

                      if (isEditing) {
                        collection.doc(document.id).update(dataToSave);
                      } else {
                        collection.add({...dataToSave, 'order': currentItemCount});
                      }
                      Navigator.of(dialogContext).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please select an item and at least one unit."), backgroundColor: Colors.orange,)
                      );
                    }
                  },
                  child: Text(isEditing ? 'Save Changes' : 'Add Item'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _backfillOrderField(List<DocumentSnapshot> items) {
    final batch = FirebaseFirestore.instance.batch();
    bool needsUpdate = false;
    for (int i = 0; i < items.length; i++) {
      final doc = items[i];
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null && data['order'] == null) {
        needsUpdate = true;
        batch.update(doc.reference, {'order': i});
      }
    }
    if (needsUpdate) {
      batch.commit().catchError((err) {
        debugPrint("Error backfilling order field: $err");
      });
    }
  }

  Future<void> _onReorder(List<DocumentSnapshot> items, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final List<DocumentSnapshot> reorderedItems = List.from(items);
    final item = reorderedItems.removeAt(oldIndex);
    reorderedItems.insert(newIndex, item);

    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < reorderedItems.length; i++) {
      batch.update(reorderedItems[i].reference, {'order': i});
    }

    try {
      await batch.commit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving order: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitsMap = ref.watch(unitsMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Butcher Request List'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('butcher_request_items')
            .orderBy('order')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final items = snapshot.data?.docs ?? [];

          if(items.isNotEmpty) {
            _backfillOrderField(items);
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final data = item.data() as Map<String, dynamic>?;
              final itemName = data?['name'] ?? 'Unnamed';

              final List<DocumentReference> unitRefs = data?['allowedUnitRefs'] != null
                  ? List<DocumentReference>.from(data?['allowedUnitRefs'])
                  : [];

              return ListTile(
                key: ValueKey(item.id),
                title: Text(itemName),
                subtitle: unitsMap.when(
                  data: (map) => Text("Units: ${unitRefs.map((ref) => map[ref.id] ?? '?').join(', ')}"),
                  loading: () => const Text("Loading units..."),
                  error: (e,s) => const Text("Error"),
                ),
                leading: const Icon(Icons.drag_handle),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showItemDialog(context, document: item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => item.reference.delete(),
                    ),
                  ],
                ),
              );
            },
            onReorder: (oldIndex, newIndex) =>
                _onReorder(items, oldIndex, newIndex),
            footer: items.isEmpty ? const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 48.0),
                  child: Text('No items created yet. Tap + to add one.'),
                )
            ) : null,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final collection = FirebaseFirestore.instance.collection('butcher_request_items');
          collection.count().get().then((value) {
            if (!mounted) return;
            _showItemDialog(context, currentItemCount: value.count ?? 0);
          });
        },
        tooltip: 'Add New Item',
        child: const Icon(Icons.add),
      ),
    );
  }
}
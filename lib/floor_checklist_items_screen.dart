// lib/floor_checklist_items_screen.dart
// This is the ADMIN screen for managing checklist items.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FloorChecklistItemsScreen extends StatefulWidget {
  const FloorChecklistItemsScreen({super.key});

  @override
  State<FloorChecklistItemsScreen> createState() =>
      _FloorChecklistItemsScreenState();
}

class _FloorChecklistItemsScreenState extends State<FloorChecklistItemsScreen> {
  void _showItemDialog(BuildContext context, {DocumentSnapshot? document, int currentItemCount = 0}) {
    final isEditing = document != null;
    final nameController = TextEditingController(
      text: isEditing ? (document.data() as Map<String, dynamic>)['name'] : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Item' : 'Add New Item'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Item Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final itemName = nameController.text.trim();
                if (itemName.isNotEmpty) {
                  final collection = FirebaseFirestore.instance
                      .collection('floor_checklist_items');
                  if (isEditing) {
                    collection.doc(document.id).update({'name': itemName});
                  } else {
                    collection.add({'name': itemName, 'order': currentItemCount});
                  }
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _backfillOrderField(List<DocumentSnapshot> items) {
    final batch = FirebaseFirestore.instance.batch();
    bool needsUpdate = false;
    for (int i = 0; i < items.length; i++) {
      final doc = items[i];
      final data = doc.data() as Map<String, dynamic>;
      if (data['order'] == null) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint("Error saving reorder: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Re-organize Floor Checklist'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('floor_checklist_items')
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

          return Stack(
            children: [
              if (items.isEmpty)
                const Center(
                    child: Text('No items created yet. Tap + to add one.')
                ),

              ReorderableListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final itemName =
                      (item.data() as Map<String, dynamic>)['name'] ?? 'Unnamed';

                  return ListTile(
                    key: ValueKey(item.id),
                    title: Text(itemName),
                    leading: const Icon(Icons.drag_handle),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              _showItemDialog(context, document: item),
                        ),
                        IconButton(
                          icon:
                          const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => item.reference.delete(),
                        ),
                      ],
                    ),
                  );
                },
                onReorder: (oldIndex, newIndex) =>
                    _onReorder(items, oldIndex, newIndex),
              ),

              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  onPressed: () =>
                      _showItemDialog(context, currentItemCount: items.length),
                  tooltip: 'Add New Item',
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
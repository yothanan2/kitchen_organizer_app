// lib/dish_management_screen.dart
// CORRECTED: Updated navigation to EditDishScreen to pass the correct parameters.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchen_organizer_app/edit_dish_screen.dart';
import 'package:kitchen_organizer_app/models/models.dart'; // <-- NEW IMPORT

enum DishFilter { active, all, components }

class DishManagementScreen extends StatefulWidget {
  const DishManagementScreen({super.key});

  @override
  State<DishManagementScreen> createState() => _DishManagementScreenState();
}

class _DishManagementScreenState extends State<DishManagementScreen> {
  DishFilter _currentFilter = DishFilter.active;

  Future<void> _toggleActiveStatus(DocumentReference dishRef, bool currentStatus) async {
    try {
      await dishRef.update({'isActive': !currentStatus});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating status: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteDish(DocumentReference dishRef) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final ingredientsSnapshot = await dishRef.collection('ingredients').get();
      for (final doc in ingredientsSnapshot.docs) { batch.delete(doc.reference); }
      final prepTasksSnapshot = await dishRef.collection('prepTasks').get();
      for (final doc in prepTasksSnapshot.docs) { batch.delete(doc.reference); }
      batch.delete(dishRef);
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dish deleted successfully"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting dish: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(DocumentSnapshot dishDoc) async {
    final dishName = (dishDoc.data() as Map<String, dynamic>)['dishName'] ?? 'Unnamed Dish';
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Deletion"),
          content: Text("Are you sure you want to permanently delete the dish '$dishName'? This will also delete all of its ingredients and prep tasks."),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.of(context).pop(true), child: const Text("Delete", style: TextStyle(color: Colors.white))),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _deleteDish(dishDoc.reference);
    }
  }

  Stream<QuerySnapshot> _getStream() {
    Query query = FirebaseFirestore.instance.collection('dishes');
    switch (_currentFilter) {
      case DishFilter.active:
        return query.where('isComponent', isEqualTo: false).where('isActive', isEqualTo: true).orderBy('dishName').snapshots();
      case DishFilter.all:
        return query.where('isComponent', isEqualTo: false).orderBy('dishName').snapshots();
      case DishFilter.components:
        return query.where('isComponent', isEqualTo: true).orderBy('dishName').snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dish Management"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SegmentedButton<DishFilter>(
              segments: const <ButtonSegment<DishFilter>>[
                ButtonSegment<DishFilter>(value: DishFilter.active, label: Text('Active Dishes'), icon: Icon(Icons.visibility)),
                ButtonSegment<DishFilter>(value: DishFilter.all, label: Text('All Dishes'), icon: Icon(Icons.list_alt)),
                ButtonSegment<DishFilter>(value: DishFilter.components, label: Text('Components'), icon: Icon(Icons.extension)),
              ],
              selected: {_currentFilter},
              onSelectionChanged: (Set<DishFilter> newSelection) {
                setState(() {
                  _currentFilter = newSelection.first;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text("An error occurred. Please ensure Firestore indexes are created.\n\nError: ${snapshot.error}", textAlign: TextAlign.center),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No dishes found for this filter."));
                }
                final dishes = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: dishes.length,
                  itemBuilder: (context, index) {
                    final dishDoc = dishes[index];
                    final dish = Dish.fromFirestore(dishDoc.data() as Map<String, dynamic>, dishDoc.id);
                    final bool isActive = dish.isActive;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: _currentFilter == DishFilter.all
                            ? Tooltip(
                          message: isActive ? 'Deactivate' : 'Activate',
                          child: Switch(
                            value: isActive,
                            onChanged: (value) => _toggleActiveStatus(dishDoc.reference, isActive),
                          ),
                        )
                            : null,
                        title: Text(
                          dish.dishName,
                          style: TextStyle(
                              color: isActive ? Colors.black : Colors.grey,
                              decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough
                          ),
                        ),
                        subtitle: Text(dish.category),
                        trailing: (_currentFilter == DishFilter.all || _currentFilter == DishFilter.components)
                            ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => EditDishScreen(dish: dish)))),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _showDeleteConfirmation(dishDoc)),
                          ],
                        )
                            : null,
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (context) => EditDishScreen(dish: dish)));
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: (_currentFilter == DishFilter.all || _currentFilter == DishFilter.components)
          ? FloatingActionButton(
        onPressed: () {
          final bool isCreatingComponent = _currentFilter == DishFilter.components;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EditDishScreen(isCreatingComponent: isCreatingComponent),
            ),
          );
        },
        tooltip: _currentFilter == DishFilter.components ? 'Add New Component' : 'Add New Dish',
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}
// lib/screens/admin/unified_dishes_screen.dart
// FINAL CORRECTION: Updated navigation to EditDishScreen to use the new constructor.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchen_organizer_app/screens/admin/edit_dish_screen.dart';
import 'package:kitchen_organizer_app/models/models.dart'; // <-- NEW IMPORT

class UnifiedDishesScreen extends StatelessWidget {
  const UnifiedDishesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dishes & Recipes'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.restaurant_menu), text: 'Dishes'),
              Tab(icon: Icon(Icons.extension), text: 'Components'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DishList(isComponent: false),
            _DishList(isComponent: true),
          ],
        ),
        floatingActionButton: Builder(builder: (context) {
          return FloatingActionButton(
            onPressed: () {
              final int currentIndex = DefaultTabController.of(context).index;
              final bool isCreatingComponent = currentIndex == 1;
              Navigator.of(context).push(
                MaterialPageRoute(
                  // UPDATED: Corrected parameter name
                  builder: (context) =>
                      EditDishScreen(isCreatingComponent: isCreatingComponent),
                ),
              );
            },
            tooltip: 'Add New',
            child: const Icon(Icons.add),
          );
        }),
      ),
    );
  }
}

class _DishList extends StatelessWidget {
  final bool isComponent;
  const _DishList({required this.isComponent});

  Stream<QuerySnapshot> _getStream() {
    return FirebaseFirestore.instance
        .collection('dishes')
        .where('isComponent', isEqualTo: isComponent)
        .orderBy('dishName')
        .snapshots();
  }

  Future<void> _showDeleteConfirmation(
      BuildContext context, DocumentSnapshot dishDoc) async {
    final dishName =
        (dishDoc.data() as Map<String, dynamic>)['dishName'] ?? 'Unknown';

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    if (isComponent) {
      // Temporarily disabled for cleanup.
      // final linkedTasksQuery = await FirebaseFirestore.instance
      //     .collectionGroup('prepTasks')
      //     .where('linkedDishRef', isEqualTo: dishDoc.reference)
      //     .get();

      // if (linkedTasksQuery.docs.isNotEmpty) {
      //   final List<String> parentDishNames = [];
      //   for (final doc in linkedTasksQuery.docs) {
      //     final parentDishDoc = await doc.reference.parent.parent!.get();
      //     if (parentDishDoc.exists) {
      //       parentDishNames.add((parentDishDoc.data() as Map<String, dynamic>)['dishName'] ?? 'Unknown Dish');
      //     }
      //   }

      //   if (!context.mounted) return;
      //   showDialog(
      //     context: context,
      //     builder: (context) => AlertDialog(
      //       title: const Text('Cannot Delete Component'),
      //       content: Text(
      //           'The component "$dishName" is used in the following dishes: \n\n- ${parentDishNames.join("\n- ")}\n\nPlease remove it from these dishes first.'),
      //       actions: [
      //         TextButton(
      //             child: const Text('OK'),
      //             onPressed: () => Navigator.of(context).pop())
      //       ],
      //     ),
      //   );
      //   return;
      // }
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Deletion"),
          content: Text(
              "Are you sure you want to permanently delete '$dishName'? This action cannot be undone."),
          actions: <Widget>[
            TextButton(
                onPressed: () => navigator.pop(false),
                child: const Text("Cancel")),
            ElevatedButton(
              style:
              ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
              onPressed: () => navigator.pop(true),
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        final ingredientsSnapshot =
        await dishDoc.reference.collection('ingredients').get();
        for (final doc in ingredientsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        final prepTasksSnapshot =
        await dishDoc.reference.collection('prepTasks').get();
        for (final doc in prepTasksSnapshot.docs) {
          batch.delete(doc.reference);
        }
        batch.delete(dishDoc.reference);
        await batch.commit();

        if (!context.mounted) return;
        messenger.showSnackBar(
          SnackBar(
              content: Text("'$dishName' deleted successfully"),
              backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!context.mounted) return;
        messenger.showSnackBar(
          SnackBar(
              content: Text("Error deleting: $e"),
              backgroundColor: theme.colorScheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("An error occurred: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                isComponent
                    ? "No components found. Press '+' to add one."
                    : "No dishes found. Press '+' to add one.",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final items = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final doc = items[index];
            // Create a Dish model object from the document data
            final dish = Dish.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(dish.dishName),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      // UPDATED: Pass the Dish object
                      builder: (context) => EditDishScreen(dish: dish),
                    ),
                  );
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            // UPDATED: Pass the Dish object
                            builder: (context) => EditDishScreen(dish: dish),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error),
                      tooltip: 'Delete',
                      onPressed: () => _showDeleteConfirmation(context, doc),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
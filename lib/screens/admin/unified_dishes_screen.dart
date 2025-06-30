// lib/screens/admin/unified_dishes_screen.dart
// FINAL STABLE VERSION

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../edit_dish_screen.dart'; // Corrected navigation target

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
              final bool isComponent = currentIndex == 1;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      EditDishScreen(isComponent: isComponent),
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
      final linkedTasksQuery = await FirebaseFirestore.instance
          .collectionGroup('prepTasks')
          .where('linkedDishRef', isEqualTo: dishDoc.reference)
          .limit(1)
          .get();

      if (!navigator.mounted) return;

      if (linkedTasksQuery.docs.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cannot Delete Component'),
            content: Text(
                'The component "$dishName" cannot be deleted because it is currently being used as a prep step in one or more dishes. Please remove it from those dishes first.'),
            actions: [
              TextButton(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(context).pop())
            ],
          ),
        );
        return;
      }
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

    if (!navigator.mounted) return;

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

        messenger.showSnackBar(
          SnackBar(
              content: Text("'$dishName' deleted successfully"),
              backgroundColor: Colors.green),
        );
      } catch (e) {
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
            final data = doc.data() as Map<String, dynamic>;
            final name = data['dishName'] ?? 'Unnamed';
            final category = data['category'] ?? 'No Category';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(name),
                subtitle: Text(category),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          EditDishScreen(dishId: doc.id),
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
                            builder: (context) =>
                                EditDishScreen(dishId: doc.id),
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
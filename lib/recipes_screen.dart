// lib/recipes_screen.dart
// NEW FILE: A screen to manage reusable recipes/components.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_edit_recipe_screen.dart'; // We will create this screen next

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  // This function handles the deletion of a recipe and its sub-collections
  Future<void> _deleteRecipe(DocumentReference recipeRef) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      final ingredientsSnapshot = await recipeRef.collection('ingredients').get();
      for (final doc in ingredientsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // A recipe (component) doesn't have its own prep tasks in our new model,
      // but it's safe to leave this here in case that changes.
      final prepTasksSnapshot = await recipeRef.collection('prepTasks').get();
      for (final doc in prepTasksSnapshot.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(recipeRef);
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Recipe deleted successfully"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting recipe: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(DocumentSnapshot recipeDoc) async {
    final recipeName = (recipeDoc.data() as Map<String, dynamic>)['dishName'] ?? 'Unnamed Recipe';

    // We should also check if this recipe is being used as a prep task in any dish.
    final recipeRef = recipeDoc.reference;
    final linkedTasksQuery = await FirebaseFirestore.instance
        .collectionGroup('prepTasks')
        .where('linkedDishRef', isEqualTo: recipeRef)
        .limit(1)
        .get();

    if (!mounted) return;

    if (linkedTasksQuery.docs.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Recipe'),
          content: Text('The recipe "$recipeName" cannot be deleted because it is currently being used as a prep step in one or more dishes. Please remove it from those dishes first.'),
          actions: [TextButton(child: const Text('OK'), onPressed: () => Navigator.of(context).pop())],
        ),
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Deletion"),
          content: Text("Are you sure you want to permanently delete the recipe '$recipeName'?"),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _deleteRecipe(recipeDoc.reference);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Recipes"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // This stream fetches only the documents marked as a component
        stream: FirebaseFirestore.instance.collection('dishes').where('isComponent', isEqualTo: true).orderBy('dishName').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("An error occurred: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No recipes found. Add one!"));
          }

          final recipes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipeDoc = recipes[index];
              final data = recipeDoc.data() as Map<String, dynamic>;
              final recipeName = data['dishName'] ?? 'Unnamed Recipe';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(recipeName),
                  onTap: () {
                    // Navigate to a screen to edit the recipe
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AddEditRecipeScreen(recipeDocument: recipeDoc),
                      ),
                    );
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => AddEditRecipeScreen(recipeDocument: recipeDoc),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _showDeleteConfirmation(recipeDoc),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to a screen to add a new recipe
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddEditRecipeScreen(),
            ),
          );
        },
        tooltip: 'Add New Recipe',
        child: const Icon(Icons.add),
      ),
    );
  }
}
// lib/categories_screen.dart
// MODIFIED: Added a button to seed the database with suggested categories.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final TextEditingController _nameController = TextEditingController();
  final CollectionReference _categoriesCollection = FirebaseFirestore.instance.collection('categories');
  bool _isSeeding = false;

  // --- NEW: The list of suggested categories ---
  static const List<String> _suggestedCategories = [
    'Vegetables - Root', 'Vegetables - Leafy Greens', 'Vegetables - Alliums', 'Vegetables - Other',
    'Fruits', 'Fresh Herbs', 'Beef', 'Pork', 'Poultry', 'Lamb & Veal', 'Seafood - Fish',
    'Seafood - Shellfish', 'Charcuterie & Cured Meats', 'Milk & Cream', 'Cheese - Hard',
    'Cheese - Soft', 'Butter & Margarine', 'Yogurt & Sour Cream', 'Eggs', 'Flour & Grains',
    'Rice & Legumes', 'Pasta - Dried', 'Canned & Jarred Goods', 'Oils', 'Vinegars & Dressings',
    'Spices & Seasonings', 'Salt & Pepper', 'Sugar & Sweeteners', 'Baking Supplies',
    'Sauces & Condiments', 'Stocks & Broths', 'Frozen Vegetables & Fruits', 'Frozen Meats & Seafood',
    'Frozen Prepared Goods', 'Ice Cream & Sorbets', 'Coffee & Tea', 'Juices & Soft Drinks',
    'Water (Still & Sparkling)', 'Wine', 'Beer', 'Spirits & Liqueurs', 'Bread', 'Pastries & Desserts',
    'Cleaning Supplies', 'Paper Goods', 'Takeout Containers & Bags', 'Kitchen Disposables'
  ];

  // --- NEW: Function to add all suggested categories in a batch ---
  Future<void> _seedInitialCategories() async {
    setState(() => _isSeeding = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final categoryName in _suggestedCategories) {
        final docRef = _categoriesCollection.doc();
        batch.set(docRef, {'name': categoryName});
      }
      await batch.commit();

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Suggested categories added successfully!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error adding categories: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSeeding = false);
      }
    }
  }

  void _showCategoryDialog({DocumentSnapshot? categoryDocument}) {
    if (categoryDocument != null) {
      final data = categoryDocument.data() as Map<String, dynamic>;
      _nameController.text = data['name'] ?? '';
    } else {
      _nameController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(categoryDocument == null ? 'Add New Category' : 'Edit Category'),
          content: TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: "Category Name"),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () async {
                final name = _nameController.text.trim();
                if (name.isEmpty) return;

                if (categoryDocument == null) {
                  await _categoriesCollection.add({'name': name});
                } else {
                  await _categoriesCollection.doc(categoryDocument.id).update({'name': name});
                }
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteConfirmDialog(String docId, String name) async {
    final categoryRef = _categoriesCollection.doc(docId);
    final linkedItemsQuery = await FirebaseFirestore.instance
        .collection('inventoryItems')
        .where('category', isEqualTo: categoryRef)
        .limit(1)
        .get();

    if (!mounted) return;

    if (linkedItemsQuery.docs.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Category'),
          content: Text('The category "$name" cannot be deleted because it is currently in use by one or more inventory items.'),
          actions: [TextButton(child: const Text('OK'), onPressed: () => Navigator.of(context).pop())],
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the category "$name"?'),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () async {
                await _categoriesCollection.doc(docId).delete();
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Categories')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _categoriesCollection.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          // --- MODIFIED: Show the "Seed" button when the list is empty ---
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: _isSeeding
                  ? const CircularProgressIndicator()
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.category_outlined, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No categories found.'),
                  const SizedBox(height: 8),
                  const Text('Add one manually or use our suggested list.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Add Suggested Categories'),
                    onPressed: _seedInitialCategories,
                  ),
                ],
              ),
            );
          }
          // --- END MODIFICATION ---

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final name = (doc.data() as Map<String, dynamic>)['name'] ?? 'Unnamed';
              return ListTile(
                title: Text(name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueGrey),
                      onPressed: () => _showCategoryDialog(categoryDocument: doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _showDeleteConfirmDialog(doc.id, name),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        tooltip: 'Add Category',
        child: const Icon(Icons.add),
      ),
    );
  }
}
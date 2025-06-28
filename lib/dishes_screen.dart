import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'prep_tasks_screen.dart'; // We will create this file next

class DishesScreen extends StatefulWidget {
  const DishesScreen({super.key});

  @override
  State<DishesScreen> createState() => _DishesScreenState();
}

class _DishesScreenState extends State<DishesScreen> {
  final TextEditingController _dishNameController = TextEditingController();

  // Function to show a dialog for adding or editing a dish name
  void _showDishDialog({DocumentSnapshot? dishDocument}) {
    if (dishDocument != null) {
      final data = dishDocument.data() as Map<String, dynamic>;
      _dishNameController.text = data['name'] ?? '';
    } else {
      _dishNameController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(dishDocument == null ? 'Add New Dish' : 'Edit Dish Name'),
          content: TextField(
            controller: _dishNameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Enter dish name"),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                final dishName = _dishNameController.text.trim();
                if (dishName.isNotEmpty) {
                  final collection = FirebaseFirestore.instance.collection('dishes');
                  if (dishDocument == null) {
                    collection.add({'name': dishName});
                  } else {
                    collection.doc(dishDocument.id).update({'name': dishName});
                  }
                  Navigator.of(context).pop();
                }
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
      appBar: AppBar(
        title: const Text('Manage Dishes (Mise en Place)'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('dishes').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No dishes defined. Add one!'));
          }

          final dishes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: dishes.length,
            itemBuilder: (context, index) {
              final dish = dishes[index];
              final data = dish.data() as Map<String, dynamic>;
              final dishName = data['name'] ?? 'Unnamed Dish';

              return ListTile(
                title: Text(dishName),
                leading: const Icon(Icons.restaurant_menu_outlined),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showDishDialog(dishDocument: dish),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PrepTasksScreen(dishDocument: dish),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDishDialog(),
        tooltip: 'Add Dish',
        child: const Icon(Icons.add),
      ),
    );
  }
}
  
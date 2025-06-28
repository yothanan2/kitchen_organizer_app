import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'prep_task_details_screen.dart'; // We will create this file next

class PrepListsScreen extends StatefulWidget {
  const PrepListsScreen({super.key});

  @override
  State<PrepListsScreen> createState() => _PrepListsScreenState();
}

class _PrepListsScreenState extends State<PrepListsScreen> {
  final TextEditingController _dishNameController = TextEditingController();
  final CollectionReference _prepListsCollection = FirebaseFirestore.instance.collection('prepLists');

  // Function to show a dialog for adding or editing a dish name
  void _showDishDialog({DocumentSnapshot? dishDocument}) {
    if (dishDocument != null) {
      final data = dishDocument.data() as Map<String, dynamic>;
      _dishNameController.text = data['dishName'] ?? '';
    } else {
      _dishNameController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(dishDocument == null ? 'Add New Dish Prep List' : 'Edit Dish Name'),
          content: TextField(
            controller: _dishNameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Enter dish name (e.g., Aragusta)"),
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
                  if (dishDocument == null) {
                    _prepListsCollection.add({'dishName': dishName, 'createdOn': FieldValue.serverTimestamp()});
                  } else {
                    _prepListsCollection.doc(dishDocument.id).update({'dishName': dishName});
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

  // Function to show a confirmation dialog before deleting a dish list
  Future<void> _showDeleteConfirmDialog(BuildContext context, DocumentSnapshot dishDoc) async {
    final dishName = (dishDoc.data() as Map<String, dynamic>)['dishName'] ?? 'this dish';
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the prep list for "$dishName"? This will also delete all its prep tasks.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () async {
                // This is a simple delete. For a large number of sub-tasks, a Cloud Function is better.
                final prepTasks = await dishDoc.reference.collection('prepTasks').get();
                for (final doc in prepTasks.docs) {
                  await doc.reference.delete();
                }
                await dishDoc.reference.delete();
                if (mounted) Navigator.of(context).pop();
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
        title: const Text('Manage Dish Prep'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _prepListsCollection.orderBy('dishName').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No dish prep lists found. Add one!'));
          }

          final dishes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: dishes.length,
            itemBuilder: (context, index) {
              final dishDoc = dishes[index];
              final data = dishDoc.data() as Map<String, dynamic>;
              final dishName = data['dishName'] ?? 'Unnamed Dish';

              return ListTile(
                title: Text(dishName),
                leading: const Icon(Icons.restaurant_outlined),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showDishDialog(dishDocument: dishDoc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _showDeleteConfirmDialog(context, dishDoc),
                    ),
                  ],
                ),
                onTap: () {
                  // This will navigate to the screen where you add the prep tasks (like "Order", "Clean")
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PrepTaskDetailsScreen(dishDocument: dishDoc),
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
        tooltip: 'Add Dish Prep List',
        child: const Icon(Icons.add),
      ),
    );
  }
}

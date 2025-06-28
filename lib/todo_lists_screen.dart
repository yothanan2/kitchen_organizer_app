import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'task_details_screen.dart'; // We will create this file next

class TodoListsScreen extends StatefulWidget {
  const TodoListsScreen({super.key});

  @override
  State<TodoListsScreen> createState() => _TodoListsScreenState();
}

class _TodoListsScreenState extends State<TodoListsScreen> {
  final TextEditingController _listNameController = TextEditingController();

  // Function to show a dialog for adding or editing a list name
  void _showListDialog({DocumentSnapshot? listDocument}) {
    if (listDocument != null) {
      final data = listDocument.data() as Map<String, dynamic>;
      _listNameController.text = data['name'] ?? '';
    } else {
      _listNameController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(listDocument == null ? 'Add New To-Do List' : 'Edit List Name'),
          content: TextField(
            controller: _listNameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Enter list name (e.g., Morning Prep)"),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                final listName = _listNameController.text.trim();
                if (listName.isNotEmpty) {
                  final collection = FirebaseFirestore.instance.collection('todoLists');
                  if (listDocument == null) {
                    collection.add({'name': listName, 'createdOn': FieldValue.serverTimestamp()});
                  } else {
                    collection.doc(listDocument.id).update({'name': listName});
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

  // Function to show a confirmation dialog before deleting a list
  Future<void> _showDeleteConfirmDialog(BuildContext context, DocumentSnapshot listDoc) async {
    final listName = (listDoc.data() as Map<String, dynamic>)['name'] ?? 'this list';
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the "$listName" list and all of its tasks?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () async {
                // In a real app, deleting subcollections should be handled by a Cloud Function.
                // For now, we do it here. This is slow if there are many tasks.
                final tasksSnapshot = await listDoc.reference.collection('tasks').get();
                for (var doc in tasksSnapshot.docs) {
                  await doc.reference.delete();
                }
                await listDoc.reference.delete();
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
        title: const Text('Define To-Do Lists'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('todoLists').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No to-do lists found. Add one!'));
          }

          final lists = snapshot.data!.docs;

          return ListView.builder(
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final listDoc = lists[index];
              final data = listDoc.data() as Map<String, dynamic>;
              final listName = data['name'] ?? 'Unnamed List';

              return ListTile(
                title: Text(listName),
                leading: const Icon(Icons.list_alt_outlined),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showListDialog(listDocument: listDoc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _showDeleteConfirmDialog(context, listDoc),
                    ),
                  ],
                ),
                onTap: () {
                  // Navigate to a new screen to manage the TASKS WITHIN this list
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TaskDetailsScreen(listDocument: listDoc),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showListDialog(),
        tooltip: 'Add List',
        child: const Icon(Icons.add),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PrepTaskDetailsScreen extends StatefulWidget {
  // This screen needs to know which dish's prep tasks to show.
  final DocumentSnapshot dishDocument;

  const PrepTaskDetailsScreen({super.key, required this.dishDocument});

  @override
  State<PrepTaskDetailsScreen> createState() => _PrepTaskDetailsScreenState();
}

class _PrepTaskDetailsScreenState extends State<PrepTaskDetailsScreen> {
  final TextEditingController _taskController = TextEditingController();

  // Function to show a dialog for adding or editing a prep task
  void _showTaskDialog({DocumentSnapshot? taskDocument}) {
    if (taskDocument != null) {
      final data = taskDocument.data() as Map<String, dynamic>;
      _taskController.text = data['taskName'] ?? '';
    } else {
      _taskController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(taskDocument == null ? 'Add New Prep Task' : 'Edit Prep Task'),
          content: TextField(
            controller: _taskController,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Enter task description"),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                final taskName = _taskController.text.trim();
                if (taskName.isNotEmpty) {
                  // Get the reference to the 'prepTasks' sub-collection for this specific dish
                  final tasksCollection = widget.dishDocument.reference.collection('prepTasks');

                  if (taskDocument == null) {
                    // Add a new task document to the sub-collection
                    tasksCollection.add({
                      'taskName': taskName,
                      'createdOn': FieldValue.serverTimestamp(),
                    });
                  } else {
                    // Update the existing task document
                    tasksCollection.doc(taskDocument.id).update({'taskName': taskName});
                  }
                  Navigator.of(context).pop(); // Close the dialog
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
    final data = widget.dishDocument.data() as Map<String, dynamic>;
    final dishName = data['dishName'] ?? 'Unnamed Dish';

    return Scaffold(
      appBar: AppBar(
        title: Text('Prep for "$dishName"'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Listen to the 'prepTasks' sub-collection of the specific dish document
        stream: widget.dishDocument.reference.collection('prepTasks').orderBy('createdOn').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No prep tasks found. Add one!'));
          }

          final tasks = snapshot.data!.docs;

          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final taskDoc = tasks[index];
              final taskData = taskDoc.data() as Map<String, dynamic>;
              final taskName = taskData['taskName'] ?? 'Unnamed Task';

              return ListTile(
                title: Text(taskName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit Button
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showTaskDialog(taskDocument: taskDoc),
                    ),
                    // Delete Button
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        // Delete the specific task document
                        widget.dishDocument.reference.collection('prepTasks').doc(taskDoc.id).delete();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      // This button adds a new prep task to this specific dish
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(),
        tooltip: 'Add Prep Task',
        child: const Icon(Icons.add),
      ),
    );
  }
}

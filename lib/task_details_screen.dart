import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TaskDetailsScreen extends StatefulWidget {
  // This screen needs to accept the to-do list document
  // so it knows which list's tasks to show.
  final DocumentSnapshot listDocument;

  const TaskDetailsScreen({super.key, required this.listDocument});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final TextEditingController _taskController = TextEditingController();

  // Function to show a dialog for adding or editing a task
  void _showTaskDialog({DocumentSnapshot? taskDocument}) {
    // If we are editing, pre-fill the text field with the existing task name
    if (taskDocument != null) {
      final data = taskDocument.data() as Map<String, dynamic>;
      _taskController.text = data['taskName'] ?? '';
    } else {
      // If adding a new task, make sure the field is clear
      _taskController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(taskDocument == null ? 'Add New Task' : 'Edit Task'),
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
                  // Get the reference to the 'tasks' sub-collection for this specific to-do list
                  final tasksCollection = widget.listDocument.reference.collection('tasks');

                  if (taskDocument == null) {
                    // Add a new task document to the sub-collection
                    tasksCollection.add({
                      'taskName': taskName,
                      'isCompleted': false, // New tasks are not completed by default
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
    // Get the name of the list from the document passed to this screen
    final data = widget.listDocument.data() as Map<String, dynamic>;
    final listName = data['name'] ?? 'Unnamed List';

    return Scaffold(
      appBar: AppBar(
        title: Text('Tasks for "$listName"'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Listen to the 'tasks' sub-collection of the specific to-do list document
        stream: widget.listDocument.reference.collection('tasks').orderBy('createdOn').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No tasks found. Add one!'));
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
                        widget.listDocument.reference.collection('tasks').doc(taskDoc.id).delete();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      // This button adds a new task to this specific list
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(),
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
    );
  }
}

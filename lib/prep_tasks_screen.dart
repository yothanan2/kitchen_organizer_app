import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PrepTasksScreen extends StatefulWidget {
  final DocumentSnapshot dishDocument;

  const PrepTasksScreen({super.key, required this.dishDocument});

  @override
  State<PrepTasksScreen> createState() => _PrepTasksScreenState();
}

class _PrepTasksScreenState extends State<PrepTasksScreen> {
  final TextEditingController _taskController = TextEditingController();

  // A reference to the 'prepTasks' sub-collection for the specific dish
  late final CollectionReference _tasksCollection;

  @override
  void initState() {
    super.initState();
    // Initialize the collection reference using the dish's document ID
    _tasksCollection = widget.dishDocument.reference.collection('prepTasks');
  }

  // Function to show a dialog for adding or editing a prep task
  void _showTaskDialog({DocumentSnapshot? taskDocument}) {
    if (taskDocument != null) {
      final data = taskDocument.data() as Map<String, dynamic>;
      _taskController.text = data['name'] ?? '';
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
            decoration: const InputDecoration(hintText: "Enter task (e.g., Cut potatoes)"),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                final taskName = _taskController.text.trim();
                if (taskName.isNotEmpty) {
                  if (taskDocument == null) {
                    // Add new task
                    _tasksCollection.add({
                      'name': taskName,
                      'isDone': false, // Default to not done
                      'completedBy': null,
                      'completedOn': null,
                    });
                  } else {
                    // Update existing task
                    _tasksCollection.doc(taskDocument.id).update({'name': taskName});
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
    // Get the dish name from the passed document for the AppBar title
    final dishData = widget.dishDocument.data() as Map<String, dynamic>;
    final dishName = dishData['name'] ?? 'Prep Tasks';

    return Scaffold(
      appBar: AppBar(
        title: Text(dishName),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Listen to the 'prepTasks' sub-collection
        stream: _tasksCollection.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No prep tasks for this dish. Add one!'));
          }

          final tasks = snapshot.data!.docs;

          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final data = task.data() as Map<String, dynamic>;
              final taskName = data['name'] ?? 'Unnamed Task';

              return ListTile(
                title: Text(taskName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showTaskDialog(taskDocument: task),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _tasksCollection.doc(task.id).delete();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(),
        tooltip: 'Add Prep Task',
        child: const Icon(Icons.add),
      ),
    );
  }
}

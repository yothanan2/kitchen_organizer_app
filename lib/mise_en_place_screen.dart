import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For formatting the date
import 'package:firebase_auth/firebase_auth.dart';

class MiseEnPlaceScreen extends StatefulWidget {
  const MiseEnPlaceScreen({super.key});

  @override
  State<MiseEnPlaceScreen> createState() => _MiseEnPlaceScreenState();
}

class _MiseEnPlaceScreenState extends State<MiseEnPlaceScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Get today's date formatted as 'yyyy-MM-dd' to match our document ID
  String get _todayDocId {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  // Function to update a task's completion status
  Future<void> _toggleTaskCompletion(DocumentReference taskRef, bool currentStatus) async {
    try {
      if (!currentStatus) {
        // If marking as complete
        await taskRef.update({
          'isCompleted': true,
          'completedByUid': currentUser?.uid,
          'completedByName': currentUser?.displayName ?? currentUser?.email,
          'completedOn': FieldValue.serverTimestamp(),
        });
      } else {
        // If un-marking as complete
        await taskRef.update({
          'isCompleted': false,
          'completedByUid': FieldValue.delete(),
          'completedByName': FieldValue.delete(),
          'completedOn': FieldValue.delete(),
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating task: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mise en Place - ${DateFormat.yMMMd().format(DateTime.now())}'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // This is the updated stream to get today's task list
        stream: FirebaseFirestore.instance
            .collection('dailyTodoLists')
            .doc(_todayDocId) // Get the document for today's date
            .collection('tasks') // Get the tasks from its sub-collection
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('Firestore Stream Error: ${snapshot.error}');
            return const Center(child: Text('Something went wrong fetching tasks.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.green),
                    const SizedBox(height: 16),
                    Text(
                      'No tasks scheduled for today!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tasks are added from the "Fill in Tasks for Tomorrow" screen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final tasks = snapshot.data!.docs;

          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final taskDocument = tasks[index];
              final data = taskDocument.data() as Map<String, dynamic>?;

              final taskName = data?['taskName'] as String? ?? 'Unnamed Task';
              final dishName = data?['dishName'] as String?;
              final isCompleted = data?['isCompleted'] as bool? ?? false;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: ListTile(
                  title: Text(
                    taskName,
                    style: TextStyle(
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? Colors.grey[600] : null,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: dishName != null && dishName.isNotEmpty ? Text('Dish: $dishName') : null,
                  leading: Checkbox(
                    value: isCompleted,
                    onChanged: (bool? value) {
                      _toggleTaskCompletion(taskDocument.reference, isCompleted);
                    },
                    activeColor: Colors.green,
                  ),
                  onTap: () {
                    _toggleTaskCompletion(taskDocument.reference, isCompleted);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

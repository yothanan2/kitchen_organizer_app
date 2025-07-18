import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchen_organizer_app/providers.dart';

class MiseEnPlaceScreen extends ConsumerStatefulWidget {
  const MiseEnPlaceScreen({super.key});

  @override
  ConsumerState<MiseEnPlaceScreen> createState() => _MiseEnPlaceScreenState();
}

class _MiseEnPlaceScreenState extends ConsumerState<MiseEnPlaceScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _toggleTaskCompletion(DocumentReference taskRef, bool currentStatus) async {
    try {
      if (!currentStatus) {
        await taskRef.update({
          'isCompleted': true,
          'completedByUid': currentUser?.uid,
          'completedByName': currentUser?.displayName ?? currentUser?.email,
          'completedOn': FieldValue.serverTimestamp(),
        });
      } else {
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
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedDateString = DateFormat('yyyy-MM-dd').format(selectedDate);
    final tasksAsync = ref.watch(tasksStreamProvider(TaskListParams(collectionPath: 'prepTasks', isCompleted: false, date: selectedDateString)));

    return Scaffold(
      appBar: AppBar(
        title: Text('Mise en Place - ${DateFormat.yMMMd().format(selectedDate)}'),
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) {
          debugPrint('Firestore Stream Error: $err');
          return const Center(child: Text('Something went wrong fetching tasks.'));
        },
        data: (snapshot) {
          if (snapshot.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.green),
                    SizedBox(height: 16),
                    Text(
                      'No tasks scheduled for today!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tasks are added from the "Fill in Tasks for Tomorrow" screen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final tasks = snapshot.docs;

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
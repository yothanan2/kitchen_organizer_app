import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kitchen_organizer_app/controllers/mise_en_place_controller.dart';
import 'package:kitchen_organizer_app/models/models.dart';
import 'package:kitchen_organizer_app/providers.dart';

class MiseEnPlaceScreen extends ConsumerWidget {
  const MiseEnPlaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masterListAsync = ref.watch(masterMiseEnPlaceProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final controller = ref.read(miseEnPlaceControllerProvider);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Mise en Place - ${DateFormat.yMMMd().format(selectedDate)}'),
      ),
      body: masterListAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) {
          debugPrint('Mise en Place Error: $err\n$stack');
          return Center(child: Text('Error loading prep list: $err'));
        },
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No items have been activated for the Mise en Place. An admin can activate them in the "Mise en Place Management" screen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(
                    task.taskName,
                    style: TextStyle(
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      color: task.isCompleted ? Colors.grey.shade600 : null,
                    ),
                  ),
                  subtitle: task.isCompleted && task.completedBy != null
                      ? Text('Completed by ${task.completedBy}')
                      : null,
                  trailing: Checkbox(
                    value: task.isCompleted,
                    onChanged: (bool? newValue) async {
                      if (newValue == null) return;
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final error = await controller.toggleTaskCompletion(
                        task,
                        newValue,
                        currentUser?.uid,
                        currentUser?.displayName?.split(' ').first ?? currentUser?.email,
                      );
                      if (error != null && context.mounted) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text(error), backgroundColor: Colors.red),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
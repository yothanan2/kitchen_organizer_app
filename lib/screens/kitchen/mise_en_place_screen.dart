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
        data: (groupedTasks) {
          if (groupedTasks.isEmpty) {
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

          final stations = ['Front', 'Hot', 'Back', 'Unassigned']
              .where((station) => groupedTasks.containsKey(station) && groupedTasks[station]!.isNotEmpty)
              .toList();

          return DefaultTabController(
            length: stations.length,
            child: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).primaryColor,
                  tabs: stations.map((station) => Tab(text: station)).toList(),
                ),
                Expanded(
                  child: TabBarView(
                    children: stations.map((station) {
                      final tasks = groupedTasks[station]!;
                      return _TaskList(tasks: tasks);
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  final List<PrepTask> tasks;
  const _TaskList({required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(miseEnPlaceControllerProvider);
    final currentUser = FirebaseAuth.instance.currentUser;

    // Group components by their parent dishes
    final componentsByDish = <String, List<PrepTask>>{};
    final unassignedComponents = <PrepTask>[];

    for (final task in tasks) {
      if (task.parentDishes.isEmpty) {
        unassignedComponents.add(task);
      } else {
        for (final dishName in task.parentDishes) {
          if (!componentsByDish.containsKey(dishName)) {
            componentsByDish[dishName] = [];
          }
          componentsByDish[dishName]!.add(task);
        }
      }
    }

    final sortedDishes = componentsByDish.keys.toList()..sort();

    return ListView.builder(
      itemCount: sortedDishes.length + (unassignedComponents.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < sortedDishes.length) {
          final dishName = sortedDishes[index];
          final components = componentsByDish[dishName]!;
          return ExpansionTile(
            title: Text(
              dishName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            initiallyExpanded: true,
            children: components.map((task) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            }).toList(),
          );
        } else {
          // Handle unassigned components
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text("Other Components", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ...unassignedComponents.map((task) {
                 return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              }),
            ],
          );
        }
      },
    );
  }
}
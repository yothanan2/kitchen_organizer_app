import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kitchen_organizer_app/models/models.dart';
import 'package:kitchen_organizer_app/providers.dart';
import 'package:kitchen_organizer_app/widgets/component_details_widget.dart';
import 'package:kitchen_organizer_app/controllers/mise_en_place_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TodaysPrepScreen extends ConsumerStatefulWidget {
  const TodaysPrepScreen({super.key});

  @override
  ConsumerState<TodaysPrepScreen> createState() => _TodaysPrepScreenState();
}

class _TodaysPrepScreenState extends ConsumerState<TodaysPrepScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final todaysPrepsAsync = ref.watch(todaysPrepsProvider);
    final controller = ref.read(miseEnPlaceControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Prep List"),
      ),
      body: todaysPrepsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (dishes) {
          if (dishes.isEmpty) {
            return const Center(
              child: Text(
                'No prep tasks for today.',
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              ),
            );
          }
          return ListView.builder(
            itemCount: dishes.length,
            itemBuilder: (context, index) {
              final dish = dishes[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                elevation: 4,
                child: ExpansionTile(
                  title: Text(dish.dishName, style: Theme.of(context).textTheme.titleLarge),
                  initiallyExpanded: true,
                  children: dish.prepTasks.map((task) {
                    final dailyStatusAsync = ref.watch(dailyCompletionProvider(DateFormat('yyyy-MM-dd').format(DateTime.now())));
                    return dailyStatusAsync.when(
                      loading: () => const ListTile(title: Text("Loading status...")),
                      error: (e, st) => ListTile(title: Text("Error status: $e")),
                      data: (dailyStatus) {
                        final isCompleted = dailyStatus[task.id]?['isCompleted'] ?? false;
                        return _buildPrepTaskTile(context, task, isCompleted, controller);
                      }
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPrepTaskTile(BuildContext context, PrepTask task, bool isCompleted, MiseEnPlaceController controller) {
    return ListTile(
      title: Text(
        task.taskName,
        style: TextStyle(
          decoration: isCompleted ? TextDecoration.lineThrough : null,
          color: isCompleted ? Colors.grey.shade700 : null,
        ),
      ),
      trailing: Checkbox(
        value: isCompleted,
        onChanged: (bool? newValue) async {
          if (newValue == null) return;
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final error = await controller.toggleTaskCompletion(
            task,
            newValue,
            currentUser?.uid,
            currentUser?.displayName?.split(' ').first ?? currentUser?.email,
          );
          if (error != null && mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.red),
            );
          }
        },
      ),
      onTap: () {
        if (task.linkedDishRef != null) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(task.taskName),
              content: SizedBox(
                width: double.maxFinite,
                child: ComponentDetailsWidget(componentRef: task.linkedDishRef!),
              ),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
            ),
          );
        }
      },
    );
  }
}


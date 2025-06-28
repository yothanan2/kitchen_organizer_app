import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'providers.dart';

class PrepareForTomorrowScreen extends ConsumerWidget {
  // ADDED: This screen now requires a date to know which list to generate.
  final DateTime forDate;

  const PrepareForTomorrowScreen({super.key, required this.forDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dishesAsyncValue = ref.watch(dishesProvider);
    final preparationState = ref.watch(preparationControllerProvider);
    final controller = ref.read(preparationControllerProvider.notifier);

    // Use a formatted string of the date for the AppBar title.
    final formattedDate = DateFormat.yMMMMd().format(forDate);

    return Scaffold(
      // MODIFIED: The AppBar title now shows the selected date.
      appBar: AppBar(title: Text("Prepare for: $formattedDate")),
      body: dishesAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (snapshot) {
          if (snapshot.docs.isEmpty) {
            return const Center(child: Text('No dishes have been created by an Admin yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: snapshot.docs.length,
            itemBuilder: (context, index) {
              final dishDoc = snapshot.docs[index];
              return _DishExpansionCard(dishDoc: dishDoc);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: preparationState.isLoading
            ? null
            : () async {
          // MODIFIED: We now pass the 'forDate' to the generateLists function.
          final error = await controller.generateLists(forDate);
          if (context.mounted) {
            if (error == null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lists for $formattedDate have been generated!")));
              Navigator.of(context).pop();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
            }
          }
        },
        // MODIFIED: The button label is also more specific.
        label: Text("Generate Lists for $formattedDate"),
        icon: preparationState.isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
            : const Icon(Icons.playlist_add_check_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _DishExpansionCard extends ConsumerWidget {
  final DocumentSnapshot dishDoc;

  const _DishExpansionCard({required this.dishDoc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dishName = (dishDoc.data() as Map<String, dynamic>)['dishName'] ?? 'Unnamed Dish';
    final category = (dishDoc.data() as Map<String, dynamic>)['category'] ?? 'No Category';
    final prepTasksAsyncValue = ref.watch(prepTasksProvider(dishDoc.reference));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ExpansionTile(
        key: PageStorageKey(dishDoc.id),
        title: Text(dishName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(category),
        children: [
          prepTasksAsyncValue.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
            error: (err, stack) => ListTile(title: Text("Error loading tasks: $err")),
            data: (taskSnapshot) {
              if (taskSnapshot.docs.isEmpty) {
                return const ListTile(title: Text("No prep tasks for this dish.", style: TextStyle(fontStyle: FontStyle.italic)));
              }
              return Column(
                children: taskSnapshot.docs.map((taskDoc) => _PrepTaskTile(taskDoc: taskDoc)).toList(),
              );
            },
          )
        ],
      ),
    );
  }
}

class _PrepTaskTile extends ConsumerWidget {
  final DocumentSnapshot taskDoc;

  const _PrepTaskTile({required this.taskDoc});

  Future<void> _showAddNoteDialog(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(preparationControllerProvider.notifier);
    final noteController = TextEditingController(text: ref.read(preparationControllerProvider).taskNotes[taskDoc.id] ?? '');

    final newNote = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add Note for: ${taskDoc['taskName']}"),
        content: TextField(
          controller: noteController,
          autofocus: true,
          decoration: const InputDecoration(hintText: "e.g., '2 cases' or 'extra thin'"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(noteController.text.trim()), child: const Text("Save Note")),
        ],
      ),
    );

    if (newNote != null) {
      controller.updateNote(taskDoc.id, newNote);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preparationState = ref.watch(preparationControllerProvider);
    final controller = ref.read(preparationControllerProvider.notifier);

    final taskId = taskDoc.id;
    final taskData = taskDoc.data() as Map<String, dynamic>;
    final taskName = taskData['taskName'] ?? 'Unnamed Task';
    final bool isStockTask = taskData['isStockRequisition'] ?? false;
    final bool isSelected = preparationState.selectedTasks[taskId] ?? false;
    final String? note = preparationState.taskNotes[taskId];

    return CheckboxListTile(
      title: Text(taskName),
      subtitle: note != null && note.isNotEmpty ? Text("Note: $note", style: const TextStyle(color: Colors.blue, fontStyle: FontStyle.italic)) : null,
      value: isSelected,
      onChanged: (selected) => controller.toggleTask(taskId, selected ?? false),
      secondary: isStockTask && isSelected
          ? IconButton(
        icon: const Icon(Icons.note_add_outlined),
        tooltip: "Add Note",
        onPressed: () => _showAddNoteDialog(context, ref),
      )
          : null,
    );
  }
}

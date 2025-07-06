import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kitchen_organizer_app/providers.dart'; // Import necessary providers like preparationControllerProvider, dishesProvider

class PreparationScreen extends ConsumerStatefulWidget {
  const PreparationScreen({super.key});

  @override
  ConsumerState<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends ConsumerState<PreparationScreen> {
  DateTime _selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dishesAsync = ref.watch(dishesProvider);
    final prepController = ref.read(preparationControllerProvider.notifier);
    final prepState = ref.watch(preparationControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Daily Lists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
            tooltip: 'Select Date',
          ),
        ],
      ),
      body: SingleChildScrollView( // Wrapped body content in SingleChildScrollView
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'List for: ${DateFormat('EEEE, MMM d, y').format(_selectedDate)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            // Removed Expanded from here as SingleChildScrollView handles vertical space
            dishesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (dishesSnapshot) {
                if (dishesSnapshot.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No dishes defined. Please add dishes first.'),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true, // Important for ListView inside SingleChildScrollView
                  physics: const NeverScrollableScrollPhysics(), // Disable ListView's own scrolling
                  itemCount: dishesSnapshot.docs.length,
                  itemBuilder: (context, index) {
                    final dishDoc = dishesSnapshot.docs[index];
                    final dishName = dishDoc['dishName'] as String;

                    final prepTasksForDish = ref.watch(prepTasksProvider(dishDoc.reference));

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ExpansionTile(
                        title: Text(dishName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        children: [
                          prepTasksForDish.when(
                            loading: () => const CircularProgressIndicator(),
                            error: (err, stack) => Text('Error loading tasks: $err'),
                            data: (tasksSnapshot) {
                              if (tasksSnapshot.docs.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('No prep tasks defined for this dish.'),
                                );
                              }
                              return Column(
                                children: tasksSnapshot.docs.map((taskDoc) {
                                  final taskData = taskDoc.data() as Map<String, dynamic>;
                                  final taskId = taskDoc.id;
                                  final taskName = taskData['taskName'] ?? 'Unnamed Task';
                                  final isSelected = prepState.selectedTasks[taskId] ?? false;
                                  final taskNote = prepState.taskNotes[taskId] ?? '';

                                  return ListTile(
                                    title: Text(taskName),
                                    leading: Checkbox(
                                      value: isSelected,
                                      onChanged: (bool? newValue) {
                                        prepController.toggleTask(taskId, newValue ?? false);
                                      },
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.notes),
                                      onPressed: () async {
                                        final note = await _showNoteDialog(context, taskNote);
                                        if (note != null) {
                                          prepController.updateNote(taskId, note);
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: prepState.isLoading
                    ? null
                    : () async {
                  final errorMessage = await prepController.generateLists(_selectedDate);
                  if (mounted) {
                    if (errorMessage == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Daily lists generated successfully!'), backgroundColor: Colors.green),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                icon: prepState.isLoading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.send),
                label: Text(prepState.isLoading ? 'Generating...' : 'Generate Lists'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showNoteDialog(BuildContext context, String currentNote) {
    final TextEditingController noteController = TextEditingController(text: currentNote);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Note'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter notes for this task',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(noteController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// lib/screens/admin/daily_notes_history_screen.dart
// UPDATED: Edit and delete buttons are now disabled for past notes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers.dart';

class DailyNotesHistoryScreen extends ConsumerStatefulWidget {
  const DailyNotesHistoryScreen({super.key});

  @override
  ConsumerState<DailyNotesHistoryScreen> createState() => _DailyNotesHistoryScreenState();
}

class _DailyNotesHistoryScreenState extends ConsumerState<DailyNotesHistoryScreen> {
  DateTime _selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final dailyDocAsync = ref.watch(dailyTodoListDocProvider(dateString));
    final todayDateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final bool isViewingToday = dateString == todayDateString;


    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Note History'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat.yMMMEd().format(_selectedDate),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: () => _selectDate(context),
                  tooltip: 'Select Date',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: dailyDocAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text("Error: $err")),
              data: (doc) {
                if (!doc.exists || doc.data() == null || (doc.data() as Map)['dailyNotes'] == null) {
                  return const Center(
                    child: Text('No notes found for this date.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  );
                }

                final notes = Map<String, dynamic>.from((doc.data() as Map)['dailyNotes']);

                if (notes.values.every((note) => note == null || note.toString().trim().isEmpty)) {
                  return const Center(
                    child: Text('No notes found for this date.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _NoteCard(
                      dateString: dateString,
                      department: 'Kitchen',
                      note: notes['forKitchenStaff'] as String?,
                      noteKey: 'forKitchenStaff',
                      isMutable: isViewingToday, // <-- Pass mutability flag
                    ),
                    _NoteCard(
                      dateString: dateString,
                      department: 'Floor',
                      note: notes['forFloorStaff'] as String?,
                      noteKey: 'forFloorStaff',
                      isMutable: isViewingToday, // <-- Pass mutability flag
                    ),
                    _NoteCard(
                      dateString: dateString,
                      department: 'Butcher',
                      note: notes['forButcherStaff'] as String?,
                      noteKey: 'forButcherStaff',
                      isMutable: isViewingToday, // <-- Pass mutability flag
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends ConsumerWidget {
  final String dateString;
  final String department;
  final String? note;
  final String noteKey;
  final bool isMutable; // <-- NEW property

  const _NoteCard({
    required this.dateString,
    required this.department,
    this.note,
    required this.noteKey,
    required this.isMutable, // <-- NEW property
  });

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final noteController = TextEditingController(text: note);
    final newNote = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit Note for $department'),
        content: TextField(
          controller: noteController,
          autofocus: true,
          maxLines: 5,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(noteController.text), child: const Text('Save')),
        ],
      ),
    );

    if (newNote != null && newNote != note) {
      try {
        await ref.read(firestoreProvider)
            .collection('dailyTodoLists')
            .doc(dateString)
            .set({'dailyNotes': {noteKey: newNote}}, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note updated successfully!'), backgroundColor: Colors.green));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating note: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteNote(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmContext) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: Text("Are you sure you want to delete the note for $department?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(confirmContext).pop(false), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(confirmContext).pop(true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if(confirmed == true) {
      try {
        await ref.read(firestoreProvider)
            .collection('dailyTodoLists')
            .doc(dateString)
            .set({'dailyNotes': {noteKey: FieldValue.delete()}}, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note deleted successfully!'), backgroundColor: Colors.orange));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting note: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (note == null || note!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Note for $department',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
            const Divider(),
            const SizedBox(height: 4),
            Text(note!, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // --- UPDATED BUTTON LOGIC ---
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  color: isMutable ? Colors.blueGrey : Colors.grey.shade300,
                  onPressed: isMutable ? () => _editNote(context, ref) : null,
                  tooltip: isMutable ? 'Edit Note' : 'Can only edit today\'s notes',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: isMutable ? Colors.redAccent : Colors.grey.shade300,
                  onPressed: isMutable ? () => _deleteNote(context, ref) : null,
                  tooltip: isMutable ? 'Delete Note' : 'Can only delete today\'s notes',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
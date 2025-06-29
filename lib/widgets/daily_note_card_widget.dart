// lib/widgets/daily_note_card_widget.dart
// NEW WIDGET: A reusable card to display the admin's daily note to a specific staff role.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';

class DailyNoteCard extends ConsumerWidget {
  // This field tells the widget which note to display ('forKitchenStaff', 'forFloorStaff', etc.)
  final String noteFieldName;

  const DailyNoteCard({
    super.key,
    required this.noteFieldName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get today's date to fetch the correct document
    final dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dailyDocAsync = ref.watch(dailyTodoListDocProvider(dateString));

    return dailyDocAsync.when(
      data: (doc) {
        if (!doc.exists) return const SizedBox.shrink();

        final data = doc.data() as Map<String, dynamic>;
        final notesMap = data['dailyNotes'] as Map<String, dynamic>?;
        final note = notesMap?[noteFieldName] as String?;

        // If there's no note for this staff type, show nothing.
        if (note == null || note.trim().isEmpty) {
          return const SizedBox.shrink();
        }

        // If there is a note, display it in a styled card.
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          color: Colors.amber.shade100,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.speaker_notes, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Text(
                      "Admin Note for Today",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.amber.shade900,
                        fontFamily: 'DistinctStyleSans', // Use header font
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Text(note, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        );
      },
      // Show nothing while loading or if there's an error fetching the note.
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}
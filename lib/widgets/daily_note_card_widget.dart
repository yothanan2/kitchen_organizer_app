// lib/widgets/daily_note_card_widget.dart
// UPDATED: Separated notes into two distinct "Post-it" widgets with random rotation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers.dart';

class DailyNoteCard extends ConsumerWidget {
  final String noteFieldName;

  const DailyNoteCard({
    super.key,
    required this.noteFieldName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dailyDocAsync = ref.watch(dailyTodoListDocProvider(dateString));

    final requisitionsStream = ref.watch(firestoreProvider)
        .collection('dailyTodoLists')
        .doc(dateString)
        .collection('stockRequisitions')
        .where('isCompleted', isEqualTo: false)
        .snapshots();

    return dailyDocAsync.when(
      data: (doc) {
        final data = doc.data() as Map<String, dynamic>?;
        final notesMap = data?['dailyNotes'] as Map<String, dynamic>?;
        final note = notesMap?[noteFieldName] as String?;
        final bool hasNote = note != null && note.trim().isNotEmpty;

        return StreamBuilder<QuerySnapshot>(
          stream: requisitionsStream,
          builder: (context, reqSnapshot) {
            if (reqSnapshot.connectionState == ConnectionState.waiting && !hasNote) {
              return const SizedBox.shrink();
            }

            final requisitions = reqSnapshot.data?.docs ?? [];
            final bool hasRequisitions = requisitions.isNotEmpty;

            if (!hasNote && !hasRequisitions) {
              return const SizedBox.shrink();
            }

            // Return a Column containing our two potential notes
            return Column(
              children: [
                if(hasNote)
                  _PostItNote(
                    title: "Admin Note for Today",
                    icon: Icons.push_pin_outlined,
                    cardColor: Colors.yellow[200]!,
                    contentColor: Colors.brown.shade700,
                    content: Text(note, style: const TextStyle(fontSize: 16, fontFamily: 'Lato')),
                  ),

                if(hasRequisitions)
                  _PostItNote(
                    title: "Today's Requisitions",
                    icon: Icons.receipt_long_outlined,
                    cardColor: Colors.lightBlue.shade100,
                    contentColor: Colors.blue.shade800,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: requisitions.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final taskName = data['taskName'] as String? ?? 'Unknown Request';
                        final displayText = taskName.startsWith("From Butcher: ") ? taskName.substring(13) : taskName;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text('• $displayText', style: const TextStyle(fontSize: 15)),
                        );
                      }).toList(),
                    ),
                  )
              ],
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}

// --- NEW REUSABLE WIDGET FOR THE POST-IT NOTE UI ---
class _PostItNote extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color cardColor;
  final Color contentColor;
  final Widget content;

  const _PostItNote({
    required this.title,
    required this.icon,
    required this.cardColor,
    required this.contentColor,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    // Generate a small, random angle for rotation each time the widget builds
    final random = Random();
    final angle = (random.nextDouble() * 4 + 1.5) * (random.nextBool() ? 1 : -1) * (pi / 180);

    return Center(
      child: Transform.rotate(
        angle: angle,
        child: Card(
          margin: const EdgeInsets.only(bottom: 24.0, left: 8, right: 8),
          color: cardColor,
          elevation: 6.0,
          shadowColor: Colors.black.withOpacity(0.4),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: contentColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: contentColor,
                            fontFamily: 'DistinctStyleSans',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16, color: Colors.black12),
                  content,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
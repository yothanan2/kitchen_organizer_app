// lib/widgets/daily_note_card_widget.dart
// FINAL VERSION: Combines correct note logic with the animated Post-it style.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../providers.dart';

class DailyNoteCard extends ConsumerStatefulWidget {
  final String noteFieldName;

  const DailyNoteCard({
    super.key,
    required this.noteFieldName,
  });

  @override
  ConsumerState<DailyNoteCard> createState() => _DailyNoteCardState();
}

class _DailyNoteCardState extends ConsumerState<DailyNoteCard> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<Color?> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _glowAnimation = ColorTween(
      begin: Colors.red.withOpacity(0.7),
      end: Colors.blue.withOpacity(0.7),
    ).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dailyDocAsync = ref.watch(dailyTodoListDocProvider(dateString));

    return dailyDocAsync.when(
      data: (doc) {
        if (!doc.exists) return const SizedBox.shrink();

        final data = doc.data() as Map<String, dynamic>;
        final notesMap = data['dailyNotes'] as Map<String, dynamic>?;
        // This is the crucial part: it uses the widget's fieldName to get the correct note.
        final note = notesMap?[widget.noteFieldName] as String?;

        if (note == null || note.trim().isEmpty) {
          return const SizedBox.shrink();
        }

        // The UI is now built using the correct note data.
        return AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Center(
              child: Transform.rotate(
                angle: -pi / 180 * 2,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _glowAnimation.value ?? Colors.transparent,
                        blurRadius: 15.0,
                        spreadRadius: 3.0,
                      ),
                    ],
                  ),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 16.0, left: 8, right: 8),
                    color: Colors.yellow[200],
                    elevation: 6.0,
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
                                  Icon(Icons.push_pin_outlined, color: Colors.brown.shade600),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Admin Note for Today",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.brown.shade700,
                                      fontFamily: 'DistinctStyleSans',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 16, color: Colors.black12),
                            Text(note, style: const TextStyle(fontSize: 16, fontFamily: 'Lato')),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}
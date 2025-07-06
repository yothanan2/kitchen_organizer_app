import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:kitchen_organizer_app/providers.dart'; // Assuming firebaseAuth and firestoreProvider are here

// Provider for the currently selected date for prep list history
final selectedPrepListDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Provider to stream prep tasks for the selected date
final prepTasksHistoryStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final selectedDate = ref.watch(selectedPrepListDateProvider);
  final dateString = DateFormat('yyyy-MM-dd').format(selectedDate);

  return firestore
      .collection('dailyTodoLists')
      .doc(dateString)
      .collection('prepTasks')
      .orderBy('createdAt') // Order by creation time
      .snapshots();
});

// Provider to stream stock requisitions for the selected date
final stockRequisitionsHistoryStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final selectedDate = ref.watch(selectedPrepListDateProvider);
  final dateString = DateFormat('yyyy-MM-dd').format(selectedDate);

  return firestore
      .collection('dailyTodoLists')
      .doc(dateString)
      .collection('stockRequisitions')
      .orderBy('createdAt') // Order by creation time
      .snapshots();
});


class PrepListHistoryScreen extends ConsumerWidget {
  const PrepListHistoryScreen({super.key});

  Future<void> _selectDate(BuildContext context, WidgetRef ref) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: ref.read(selectedPrepListDateProvider),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != ref.read(selectedPrepListDateProvider)) {
      ref.read(selectedPrepListDateProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedPrepListDateProvider);
    final prepTasksAsync = ref.watch(prepTasksHistoryStreamProvider);
    final stockReqsAsync = ref.watch(stockRequisitionsHistoryStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Prep List History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context, ref),
            tooltip: 'Select Date',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_left),
                  onPressed: () {
                    ref.read(selectedPrepListDateProvider.notifier).state =
                        selectedDate.subtract(const Duration(days: 1));
                  },
                ),
                Expanded(
                  child: Text(
                    DateFormat('EEEE, MMM d, y').format(selectedDate),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_right),
                  onPressed: () {
                    ref.read(selectedPrepListDateProvider.notifier).state =
                        selectedDate.add(const Duration(days: 1));
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildTaskList(
                    context,
                    title: 'Prep Tasks',
                    stream: prepTasksAsync,
                  ),
                ),
                Expanded(
                  child: _buildTaskList(
                    context,
                    title: 'Stock Requisitions',
                    stream: stockReqsAsync,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(BuildContext context, {required String title, required AsyncValue<QuerySnapshot> stream}) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: stream.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text("Error: $err")),
              data: (snapshot) {
                if (snapshot.docs.isEmpty) {
                  return Center(
                    child: Text('No $title for this date.', textAlign: TextAlign.center),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  itemCount: snapshot.docs.length,
                  itemBuilder: (context, index) {
                    final task = snapshot.docs[index].data() as Map<String, dynamic>;
                    final taskName = task['taskName'] ?? 'Unnamed Task';
                    final isCompleted = task['isCompleted'] ?? false;
                    final note = task['note'] ?? '';
                    final reportedBy = task['reportedBy'] ?? '';

                    return ListTile(
                      title: Text(
                        taskName,
                        style: TextStyle(
                          decoration: isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                          color: isCompleted ? Colors.grey : Colors.black,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (note.isNotEmpty) Text('Note: $note', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                          if (reportedBy.isNotEmpty) Text('Reported by: $reportedBy', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                        ],
                      ),
                      trailing: isCompleted
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

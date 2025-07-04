// lib/butcher_dashboard_screen.dart
// UPDATED: Centered all header text widgets.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'providers.dart';
import 'butcher_requisition_screen.dart';
import 'widgets/weather_card_widget.dart';
import 'widgets/daily_note_card_widget.dart';

class ButcherDashboardScreen extends ConsumerWidget {
  const ButcherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider).value;
    final displayName = appUser?.fullName?.split(' ').first ?? 'Butcher';

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $displayName!'),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut(), tooltip: 'Logout')],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(weatherProvider);
          ref.invalidate(dailyTodoListDocProvider(ref.read(todayDocIdProvider(DateTime.now()))));
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WeatherCard(),
                const SizedBox(height: 16),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ButcherRequisitionScreen()));
                  },
                  icon: const Icon(Icons.note_add_outlined, size: 28),
                  label: const Text(
                    "Create Daily Requisition",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 70),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                  ),
                ),
                const SizedBox(height: 24),

                const DailyNoteCard(noteFieldName: 'forButcherStaff'),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                Center( // <-- UPDATED
                    child: Text("Today's Requisitions", style: Theme.of(context).textTheme.headlineSmall)
                ),
                const SizedBox(height: 8),
                const _RequestedItemsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestedItemsList extends StatelessWidget {
  const _RequestedItemsList();

  Stream<QuerySnapshot<Map<String, dynamic>>> _getRequisitionsStream() {
    final firestore = FirebaseFirestore.instance;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return firestore
        .collection('dailyTodoLists')
        .doc(today)
        .collection('stockRequisitions')
        .where('category', isEqualTo: 'Butcher Requisition')
        .snapshots();
  }

  Future<void> _markAsReceived(DocumentReference taskRef) async {
    await taskRef.update({'isCompleted': true});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getRequisitionsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error loading requisitions: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text("No items requested for today.", style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final pending = docs.where((doc) => (doc.data() as Map<String, dynamic>)['isCompleted'] == false).toList();
        final completed = docs.where((doc) => (doc.data() as Map<String, dynamic>)['isCompleted'] == true).toList();

        if (pending.isEmpty && completed.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text("No items requested for today.", style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if(pending.isNotEmpty)
              _buildTaskList(
                context: context,
                title: 'Pending Receipt',
                tasks: pending,
                isPending: true,
                onTap: (doc) => _markAsReceived(doc.reference),
              ),

            if (completed.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildTaskList(
                context: context,
                title: 'Received Today',
                tasks: completed,
                isPending: false,
              ),
            ]
          ],
        );
      },
    );
  }

  Widget _buildTaskList({
    required BuildContext context,
    required String title,
    required List<DocumentSnapshot> tasks,
    required bool isPending,
    Function(DocumentSnapshot)? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center( // <-- UPDATED
            child: Text(title, style: Theme.of(context).textTheme.titleLarge)
        ),
        const SizedBox(height: 8),
        ListView.builder(
          itemCount: tasks.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final task = tasks[index];
            final data = task.data() as Map<String, dynamic>;
            final taskName = data['taskName'] ?? 'Unnamed Task';
            return Card(
              elevation: 2,
              color: isPending ? null : Colors.grey.shade200,
              child: ListTile(
                title: Text(
                  taskName,
                  style: TextStyle(
                    decoration: isPending ? null : TextDecoration.lineThrough,
                    color: isPending ? null : Colors.grey.shade700,
                  ),
                ),
                trailing: isPending
                    ? ElevatedButton(
                  onPressed: () => onTap?.call(task),
                  child: const Text('Mark Received'),
                )
                    : const Icon(Icons.check_circle, color: Colors.green),
              ),
            );
          },
        ),
      ],
    );
  }
}
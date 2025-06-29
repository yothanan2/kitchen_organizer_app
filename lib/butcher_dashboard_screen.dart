// lib/butcher_dashboard_screen.dart
// UPDATED: Replaced private note cards with the reusable DailyNoteCard widget.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'providers.dart';
import 'butcher_requisition_screen.dart';
import 'widgets/weather_card_widget.dart';
import 'widgets/daily_note_card_widget.dart'; // <-- NEW IMPORT

class ButcherDashboardScreen extends ConsumerWidget {
  const ButcherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider).value;
    final displayName = appUser?.fullName?.split(' ').first ?? 'Butcher';
    final dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $displayName!'),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut(), tooltip: 'Logout')],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(weatherProvider);
          ref.invalidate(dailyTodoListDocProvider(dateString));
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const WeatherCard(),
                const SizedBox(height: 16),
                // NEW: Added the daily note card for butcher staff
                const DailyNoteCard(noteFieldName: 'forButcherStaff'),
                _KitchenNoteForButcherCard(dateString: dateString), // Keep this for now
                const SizedBox(height: 24),
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
                Text(
                  "Other butcher tools will appear here.",
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// This specific note from the kitchen can remain a private widget for now.
class _KitchenNoteForButcherCard extends ConsumerWidget {
  final String dateString;
  const _KitchenNoteForButcherCard({required this.dateString});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyDocAsync = ref.watch(dailyTodoListDocProvider(dateString));
    return dailyDocAsync.when(
      data: (doc) {
        if (!doc.exists) return const SizedBox.shrink();
        final data = doc.data() as Map<String, dynamic>;
        final note = data['kitchenToButcherNote'] as String?;
        if (note == null || note.trim().isEmpty) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: Colors.lightBlue.shade100,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.soup_kitchen_outlined, color: Colors.blue.shade800),
                    const SizedBox(width: 8),
                    Text("Note from the Kitchen", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900, fontFamily: 'DistinctStyleSans')),
                  ],
                ),
                const Divider(height: 16),
                Text(note, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e,s) => const SizedBox.shrink(),
    );
  }
}
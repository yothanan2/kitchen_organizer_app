// lib/butcher_dashboard_screen.dart
// UPDATED: Replaced private note cards with the reusable DailyNoteCard widget.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'providers.dart';
import 'butcher_requisition_screen.dart';
import 'widgets/weather_card_widget.dart';
import 'widgets/daily_note_card_widget.dart'; // <-- NEW IMPORT

class ButcherDashboardScreen extends ConsumerWidget { // Can be a ConsumerWidget now
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
          // In a real app, you might want to invalidate other date-specific providers here too.
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
                // The private _KitchenNoteForButcherCard is removed and would be handled by a different mechanism if needed.
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
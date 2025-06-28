// lib/butcher_dashboard_screen.dart
// CORRECTED: Updated to pass the current date to the daily note providers.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'providers.dart';
import 'butcher_requisition_screen.dart';

Color _getWeatherCardColor(String weatherDescription) {
  String lowerCaseDesc = weatherDescription.toLowerCase();
  if (lowerCaseDesc.contains('clear') || lowerCaseDesc.contains('sun')) return Colors.amber.shade100;
  if (lowerCaseDesc.contains('cloudy') || lowerCaseDesc.contains('overcast')) return Colors.blueGrey.shade50;
  if (lowerCaseDesc.contains('rain') || lowerCaseDesc.contains('drizzle') || lowerCaseDesc.contains('showers')) return Colors.lightBlue.shade100;
  if (lowerCaseDesc.contains('snow')) return Colors.blue.shade50;
  if (lowerCaseDesc.contains('thunderstorm')) return Colors.indigo.shade100;
  if (lowerCaseDesc.contains('fog')) return Colors.grey.shade200;
  return Colors.grey.shade100;
}
Color _getTextColor(Color backgroundColor) {
  return backgroundColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
}

class ButcherDashboardScreen extends ConsumerStatefulWidget {
  const ButcherDashboardScreen({super.key});
  @override
  ConsumerState<ButcherDashboardScreen> createState() => _ButcherDashboardScreenState();
}

class _ButcherDashboardScreenState extends ConsumerState<ButcherDashboardScreen> {
  @override
  Widget build(BuildContext context) {
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
          // Pass today's date string when invalidating
          final dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
          ref.invalidate(dailyTodoListDocProvider(dateString));
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const _WeatherCard(),
                const _AdminNoteForButcherCard(),
                const _KitchenNoteForButcherCard(),
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
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
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

class _WeatherCard extends ConsumerWidget {
  const _WeatherCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherProvider);
    return weatherAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('Weather Error: ${err.toString()}', style: const TextStyle(color: Colors.red))),
      data: (weather) {
        Color cardColor = _getWeatherCardColor(weather.dailyWeatherDescription);
        Color textColor = _getTextColor(cardColor);
        final precipitationInfo = weather.findFirstPrecipitation();
        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 16.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 2, blurRadius: 5, offset: const Offset(0, 3))]),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current: ${weather.currentTemp.toStringAsFixed(1)}°C', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                    Text('${weather.weatherIcon} ${weather.weatherDescription}', style: TextStyle(fontSize: 16, color: textColor)),
                    const SizedBox(height: 8),
                    Text('Today: ${weather.dailyWeatherIcon} ${weather.dailyWeatherDescription}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                    if (precipitationInfo != null) ...[
                      const SizedBox(height: 8),
                      Text('❗️ $precipitationInfo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.9))),
                    ]
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Max: ${weather.maxTemp.toStringAsFixed(1)}°C', style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.7))),
                  Text('Min: ${weather.minTemp.toStringAsFixed(1)}°C', style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.7))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
class _AdminNoteForButcherCard extends ConsumerWidget {
  const _AdminNoteForButcherCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // UPDATED: Pass today's date string to the provider
    final dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dailyDocAsync = ref.watch(dailyTodoListDocProvider(dateString));

    return dailyDocAsync.when(
      data: (doc) {
        if (!doc.exists) return const SizedBox.shrink();
        final data = doc.data() as Map<String, dynamic>;
        final notesMap = data['dailyNotes'] as Map<String, dynamic>?;
        final note = notesMap?['forButcherStaff'] as String?;
        if (note == null || note.trim().isEmpty) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
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
                    Text("Admin Note for Today", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber.shade900)),
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
class _KitchenNoteForButcherCard extends ConsumerWidget {
  const _KitchenNoteForButcherCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // UPDATED: Pass today's date string to the provider
    final dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
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
                    Text("Note from the Kitchen", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900)),
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
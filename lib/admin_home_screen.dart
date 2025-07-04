// lib/admin_home_screen.dart
// V15: Added button to navigate to note history screen.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'user_management_screen.dart';
import 'analytics_screen.dart';
import 'screens/admin/system_management_screen.dart';
import 'screens/admin/daily_notes_history_screen.dart'; // <-- NEW IMPORT
import 'widgets/weather_card_widget.dart';

class AdminHomeScreen extends ConsumerWidget {
  final VoidCallback? onToggleView;

  const AdminHomeScreen({super.key, this.onToggleView});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App?'),
            content: const Text('Are you sure you want to close the app?'),
            actions: [
              TextButton(child: const Text('No'), onPressed: () => Navigator.of(context).pop(false)),
              TextButton(child: const Text('Yes'), onPressed: () => Navigator.of(context).pop(true)),
            ],
          ),
        ).then((shouldPop) {
          if (shouldPop ?? false) {
            SystemNavigator.pop();
          }
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            if (onToggleView != null)
              Tooltip(message: 'Switch to Staff View', child: IconButton(icon: const Icon(Icons.switch_account), onPressed: onToggleView)),
            IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut(), tooltip: 'Logout'),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            const WeatherCard(),
            const SizedBox(height: 16),
            const _DailyInfoCard(),
            const SizedBox(height: 24),

            _buildMenuButton(
              context,
              title: 'Manage Users',
              icon: Icons.people_outline,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const UserManagementScreen())),
            ),
            const SizedBox(height: 12),
            _buildMenuButton(
              context,
              title: 'Analytics & Reports',
              icon: Icons.bar_chart_outlined,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AnalyticsScreen())),
            ),
            const SizedBox(height: 12),
            _buildMenuButton(
              context,
              title: 'System Management',
              icon: Icons.settings_outlined,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SystemManagementScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(title),
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 60),
        textStyle: Theme.of(context).textTheme.labelLarge,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    );
  }
}

class _DailyInfoCard extends ConsumerStatefulWidget {
  const _DailyInfoCard();

  @override
  ConsumerState<_DailyInfoCard> createState() => _DailyInfoCardState();
}

class _DailyInfoCardState extends ConsumerState<_DailyInfoCard> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();

    ref.listenManual<DailyNoteState>(dailyNoteControllerProvider, (prev, next) {
      if (_noteController.text != next.noteText) {
        _noteController.text = next.noteText;
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dailyNoteState = ref.watch(dailyNoteControllerProvider);
    final dailyNoteController = ref.read(dailyNoteControllerProvider.notifier);

    return Card(
      elevation: 4,
      color: Colors.blue.shade50,
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Center(
          child: Text(
            "Send a Note to Departments",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
          ),
        ),
        initiallyExpanded: true,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          SegmentedButton<NoteAudience>(
            segments: const [
              ButtonSegment(value: NoteAudience.floor, label: Text('Floor'), icon: Icon(Icons.deck_outlined)),
              ButtonSegment(value: NoteAudience.kitchen, label: Text('Kitchen'), icon: Icon(Icons.soup_kitchen_outlined)),
              ButtonSegment(value: NoteAudience.butcher, label: Text('Butcher'), icon: Icon(Icons.set_meal_outlined)),
              ButtonSegment(value: NoteAudience.both, label: Text('All Staff'), icon: Icon(Icons.groups_outlined)),
            ],
            selected: {dailyNoteState.selectedAudience},
            onSelectionChanged: (Set<NoteAudience> newSelection) {
              dailyNoteController.setAudience(newSelection.first);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            onChanged: dailyNoteController.updateNoteText,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: "Enter today's info here",
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // --- NEW HISTORY BUTTON ---
              TextButton.icon(
                icon: const Icon(Icons.history, size: 20),
                label: const Text("View History"),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DailyNotesHistoryScreen()));
                },
              ),
              ElevatedButton.icon(
                onPressed: dailyNoteState.isSaving
                    ? null
                    : () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final error = await dailyNoteController.saveNote();
                  if (mounted) {
                    if (error == null) {
                      scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Daily info saved!"), backgroundColor: Colors.green));
                    } else {
                      scaffoldMessenger.showSnackBar(SnackBar(content: Text("Error: $error"), backgroundColor: Colors.red));
                    }
                  }
                },
                icon: dailyNoteState.isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_outlined),
                label: const Text('Send Out'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
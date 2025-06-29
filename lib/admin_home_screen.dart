// lib/admin_home_screen.dart
// UPDATED: Navigation for 'Dishes & Recipes' now points to the new UnifiedDishesScreen.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'user_management_screen.dart';
import 'inventory_overview_screen.dart';
import 'shopping_list_screen.dart';
import 'floor_checklist_items_screen.dart';
import 'providers.dart';
import 'butcher_requisition_screen.dart';
import 'analytics_screen.dart';
import 'widgets/weather_card_widget.dart';
import 'screens/admin/unified_dishes_screen.dart'; // <-- CHANGED IMPORT

class AdminHomeScreen extends ConsumerWidget {
  final VoidCallback? onToggleView;

  const AdminHomeScreen({super.key, this.onToggleView});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unapprovedUsersCount = ref.watch(unapprovedUsersCountProvider);
    final lowStockItemsCount = ref.watch(lowStockItemsCountProvider);

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
            _buildMetricCard(
              context: context,
              title: 'Pending Approvals',
              icon: Icons.person_add_outlined,
              asyncValue: unapprovedUsersCount,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const UserManagementScreen())),
            ),
            const SizedBox(height: 8),
            _buildMetricCard(
              context: context,
              title: 'Low-Stock Items',
              icon: Icons.warning_amber_rounded,
              asyncValue: lowStockItemsCount,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const InventoryOverviewScreen())),
            ),
            const SizedBox(height: 16),
            const _DailyNoteCard(),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            // --- THIS IS THE MODIFIED BUTTON ---
            _buildMenuButton(context, title: 'Dishes & Recipes', icon: Icons.restaurant_menu_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const UnifiedDishesScreen()))),
            const SizedBox(height: 12),
            _buildMenuButton(context, title: 'Inventory Management', icon: Icons.inventory_2_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const InventoryOverviewScreen()))),
            const SizedBox(height: 12),
            _buildMenuButton(context, title: 'Butcher Requisition Form', icon: Icons.set_meal_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ButcherRequisitionScreen()))),
            const SizedBox(height: 12),
            _buildMenuButton(context, title: 'Manage Floor Checklist', icon: Icons.deck_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const FloorChecklistItemsScreen()))),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            _buildMenuButton(context, title: 'Manage Users', icon: Icons.people_outline, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const UserManagementScreen()))),
            const SizedBox(height: 12),
            _buildMenuButton(context, title: 'Generate Shopping List', icon: Icons.shopping_cart_checkout_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ShoppingListScreen()))),
            const SizedBox(height: 12),
            _buildMenuButton(context, title: 'Analytics & Reports', icon: Icons.bar_chart_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AnalyticsScreen()))),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required AsyncValue<int> asyncValue,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Theme.of(context).primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              asyncValue.when(
                loading: () => const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                error: (err, stack) => Icon(Icons.error_outline, color: Colors.red.shade700),
                data: (count) {
                  if (count == 0) {
                    return const Icon(Icons.check_circle_outline, color: Colors.green, size: 30);
                  }
                  return CircleAvatar(
                    radius: 15,
                    backgroundColor: title == 'Pending Approvals' ? Colors.red.shade700 : Colors.orange.shade800,
                    child: Text(
                      count.toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            ],
          ),
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
        textStyle: const TextStyle(fontSize: 18),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    );
  }
}

class _DailyNoteCard extends ConsumerStatefulWidget {
  const _DailyNoteCard();

  @override
  ConsumerState<_DailyNoteCard> createState() => _DailyNoteCardState();
}

class _DailyNoteCardState extends ConsumerState<_DailyNoteCard> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _loadInitialNote();
  }

  void _loadInitialNote() {
    final dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    ref.read(dailyTodoListDocProvider(dateString).future).then((doc) {
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        final notesMap = data['dailyNotes'] as Map<String, dynamic>?;
        _noteController.text = notesMap?['forKitchenStaff'] ?? notesMap?['forFloorStaff'] ?? notesMap?['forButcherStaff'] ?? '';
      }
    });
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Daily Note", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
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
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Enter today's note here",
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: dailyNoteState.isSaving
                  ? null
                  : () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final error = await dailyNoteController.saveNote(_noteController.text);
                if (mounted) {
                  if (error == null) {
                    scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Daily note saved!"), backgroundColor: Colors.green));
                  } else {
                    scaffoldMessenger.showSnackBar(SnackBar(content: Text("Error: $error"), backgroundColor: Colors.red));
                  }
                }
              },
              icon: dailyNoteState.isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: const Text('Save Note'),
            ),
          ],
        ),
      ),
    );
  }
}
// lib/admin_home_screen.dart
// REDESIGN V1: Grouped management buttons into a collapsible ExpansionTile.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/admin/unified_dishes_screen.dart';
import 'user_management_screen.dart';
import 'inventory_overview_screen.dart';
import 'shopping_list_screen.dart';
import 'floor_checklist_items_screen.dart';
import 'providers.dart';
import 'butcher_requisition_screen.dart';
import 'analytics_screen.dart';
import 'widgets/weather_card_widget.dart';

class AdminHomeScreen extends ConsumerWidget {
  final VoidCallback? onToggleView;

  const AdminHomeScreen({super.key, this.onToggleView});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unapprovedUsersCount = ref.watch(unapprovedUsersCountProvider);

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
            unapprovedUsersCount.when(
              data: (count) {
                if (count > 0) {
                  return Column(
                    children: [
                      _buildMetricCard(
                        context: context,
                        title: 'Pending Approvals',
                        icon: Icons.person_add_outlined,
                        asyncValue: unapprovedUsersCount,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const UserManagementScreen())),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (err, stack) => const SizedBox.shrink(),
            ),
            const _DailyNoteCard(),
            const SizedBox(height: 24),

            // --- NEW: System Management ExpansionTile ---
            Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: ExpansionTile(
                title: Text("System Management", style: Theme.of(context).textTheme.titleLarge),
                leading: const Icon(Icons.settings_outlined),
                initiallyExpanded: false, // Start collapsed
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  _buildManagementTile(
                    context,
                    title: 'Dish & Recipe Management',
                    icon: Icons.restaurant_menu_outlined,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const UnifiedDishesScreen())),
                  ),
                  _buildManagementTile(
                    context,
                    title: 'Inventory Management',
                    icon: Icons.inventory_2_outlined,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const InventoryOverviewScreen())),
                  ),
                  _buildManagementTile(
                    context,
                    title: 'Manage Users',
                    icon: Icons.people_outline,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const UserManagementScreen())),
                  ),
                  _buildManagementTile(
                    context,
                    title: 'Manage Floor Checklist',
                    icon: Icons.deck_outlined,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const FloorChecklistItemsScreen())),
                  ),
                ],
              ),
            ),
            // --- END NEW WIDGET ---

            const SizedBox(height: 8),

            // --- Operations & Reports Buttons (Unchanged for now) ---
            _buildMenuButton(context, title: 'Butcher Requisition Form', icon: Icons.set_meal_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ButcherRequisitionScreen()))),
            const SizedBox(height: 12),
            _buildMenuButton(context, title: 'Generate Shopping List', icon: Icons.shopping_cart_checkout_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ShoppingListScreen()))),
            const SizedBox(height: 12),
            _buildMenuButton(context, title: 'Analytics & Reports', icon: Icons.bar_chart_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AnalyticsScreen()))),
          ],
        ),
      ),
    );
  }

  // NEW: Helper for tiles inside the ExpansionPanel for a cleaner look
  Widget _buildManagementTile(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
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
                  style: Theme.of(context).textTheme.titleLarge,
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
        textStyle: Theme.of(context).textTheme.labelLarge,
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Daily Note", style: Theme.of(context).textTheme.titleLarge),
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
              onChanged: dailyNoteController.updateNoteText,
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
                final error = await dailyNoteController.saveNote();
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
                  : const Icon(Icons.send_outlined),
              label: const Text('Send Out'),
            ),
          ],
        ),
      ),
    );
  }
}
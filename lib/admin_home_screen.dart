// lib/admin_home_screen.dart
// REDESIGN V2: Added the new dynamic ActionItemsCard.

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
import 'staff_low_stock_screen.dart';
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

            const _ActionItemsCard(), // <-- NEW DYNAMIC CARD

            const _DailyNoteCard(),
            const SizedBox(height: 24),

            _buildMenuButton(context, title: 'Analytics & Reports', icon: Icons.bar_chart_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AnalyticsScreen()))),
            const SizedBox(height: 12),

            Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: ExpansionTile(
                title: Text("System Management", style: Theme.of(context).textTheme.titleLarge),
                leading: const Icon(Icons.settings_outlined),
                initiallyExpanded: false,
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
          ],
        ),
      ),
    );
  }

  Widget _buildManagementTile(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
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


// --- NEW WIDGET FOR THE ACTIONABLE ITEMS CARD ---
class _ActionItemsCard extends ConsumerWidget {
  const _ActionItemsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingApprovals = ref.watch(unapprovedUsersCountProvider);
    final lowStockItems = ref.watch(lowStockItemsCountProvider);
    final openRequisitions = ref.watch(openRequisitionsCountProvider);

    final items = <Widget>[];

    pendingApprovals.whenData((count) {
      if (count > 0) {
        items.add(_buildMetricRow(
          context,
          title: 'Pending Approvals',
          icon: Icons.person_add_outlined,
          count: count,
          color: Colors.red.shade700,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const UserManagementScreen())),
        ));
      }
    });

    lowStockItems.whenData((count) {
      if (count > 0) {
        items.add(_buildMetricRow(
          context,
          title: 'Low-Stock Items',
          icon: Icons.warning_amber_rounded,
          count: count,
          color: Colors.orange.shade800,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const StaffLowStockScreen())),
        ));
      }
    });

    openRequisitions.whenData((count) {
      if (count > 0) {
        items.add(_buildMetricRow(
          context,
          title: 'New Requisitions',
          icon: Icons.receipt_long_outlined,
          count: count,
          color: Colors.blue.shade700,
          onTap: () {
            // In the future, this could navigate to a dedicated requisitions screen
            // For now, we can re-use the shopping list screen as it's relevant
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ShoppingListScreen()));
          },
        ));
      }
    });

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Action Items", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(BuildContext context, {required String title, required IconData icon, required int count, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            CircleAvatar(
              radius: 14,
              backgroundColor: color,
              child: Text(
                count.toString(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
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
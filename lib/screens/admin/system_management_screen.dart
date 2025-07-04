// lib/screens/admin/system_management_screen.dart
// UPDATED: Renamed butcher form link to point to the new management screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../user_management_screen.dart';
import '../../inventory_overview_screen.dart';
import '../../shopping_list_screen.dart';
import '../../floor_checklist_items_screen.dart';
import '../../providers.dart';
import '../../analytics_screen.dart';
import 'unified_dishes_screen.dart';
import 'manage_butcher_list_screen.dart'; // <-- NEW IMPORT

class SystemManagementScreen extends ConsumerWidget {
  const SystemManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unapprovedUsersCount = ref.watch(unapprovedUsersCountProvider);
    final openRequisitionsCount = ref.watch(openRequisitionsCountProvider);
    final lowStockItemsCount = ref.watch(lowStockItemsCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("System Management"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          unapprovedUsersCount.when(
            data: (count) => count > 0 ? _buildManagementTile(
              context,
              title: 'Pending Approvals',
              icon: Icons.person_add_outlined,
              count: count,
              badgeColor: Colors.red.shade700,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const UserManagementScreen())),
            ) : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(), error: (e,s) => const SizedBox.shrink(),
          ),
          openRequisitionsCount.when(
            data: (count) => count > 0 ? _buildManagementTile(
              context,
              title: 'New Requisitions',
              icon: Icons.receipt_long_outlined,
              count: count,
              badgeColor: Colors.blue.shade700,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ShoppingListScreen())),
            ) : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(), error: (e,s) => const SizedBox.shrink(),
          ),
          lowStockItemsCount.when(
            data: (count) => count > 0 ? _buildManagementTile(
              context,
              title: 'Low-Stock Items',
              icon: Icons.warning_amber_rounded,
              count: count,
              badgeColor: Colors.orange.shade800,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ShoppingListScreen())),
            ) : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(), error: (e,s) => const SizedBox.shrink(),
          ),

          const Divider(height: 32),
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
          // --- UPDATED TILE ---
          _buildManagementTile(
            context,
            title: 'Manage Butcher List', // <-- RENAMED
            icon: Icons.format_list_bulleted_outlined,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ManageButcherListScreen())), // <-- NEW NAVIGATION
          ),
          _buildManagementTile(
            context,
            title: 'Floor Requisition Form',
            icon: Icons.deck_outlined,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const FloorChecklistItemsScreen())),
          ),
          const Divider(height: 32),
          _buildManagementTile(
            context,
            title: 'Analytics & Reports',
            icon: Icons.bar_chart_outlined,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AnalyticsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementTile(BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    int? count,
    Color? badgeColor,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if(count != null && count > 0)
              CircleAvatar(
                radius: 12,
                backgroundColor: badgeColor ?? Colors.red,
                child: Text(
                  count.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
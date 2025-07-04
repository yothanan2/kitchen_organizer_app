// lib/staff_wrapper_screen.dart
// V3: Added notification bell and fixed view-switching logic.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'staff_home_screen.dart';
import 'staff_inventory_count_screen.dart';
import 'providers.dart';
import 'home_screen.dart'; // Import to access the view provider
import 'widgets/notification_bell_widget.dart'; // Import the new bell widget

class StaffWrapperScreen extends ConsumerWidget {
  const StaffWrapperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider).value;

    return DefaultTabController(
      length: 2, // We have two tabs: Today and Inventory
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Staff Dashboard'),
          actions: [
            // This is the new notification bell.
            const NotificationBellWidget(),

            // This button allows an Admin to switch back to the Admin view.
            if (appUser?.role == 'Admin')
              Tooltip(
                message: 'Switch to Admin View',
                child: IconButton(
                  icon: const Icon(Icons.admin_panel_settings),
                  // CORRECTED: This now uses the provider to correctly switch views.
                  onPressed: () {
                    ref.read(isViewingAsStaffProvider.notifier).state = false;
                  },
                ),
              ),

            // The standard logout button.
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut(),
              tooltip: 'Logout',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.today), text: 'Today'),
              Tab(icon: Icon(Icons.inventory), text: 'Inventory'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // Page 1: The main staff dashboard
            StaffHomeScreen(),
            // Page 2: The inventory counting screen
            StaffInventoryCountScreen(),
          ],
        ),
      ),
    );
  }
}
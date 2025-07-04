// lib/staff_wrapper_screen.dart
// V2: Converted to use a TabBar at the top instead of a BottomNavigationBar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'staff_home_screen.dart';
import 'staff_inventory_count_screen.dart'; // Ensure this is the correct screen for inventory
import 'providers.dart';

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
            // This button allows an Admin to switch back to the Admin view
            if (appUser?.role == 'Admin')
              Tooltip(
                message: 'Switch to Admin View',
                child: IconButton(
                  icon: const Icon(Icons.admin_panel_settings),
                  onPressed: () {
                    // This logic assumes you have a way to switch views,
                    // for now, we'll just sign out as a placeholder if needed.
                    // Ideally, you'd have a provider to toggle the view.
                    FirebaseAuth.instance.signOut();
                  },
                ),
              ),
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
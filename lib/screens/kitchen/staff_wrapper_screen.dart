// lib/staff_wrapper_screen.dart
// V3: Added notification bell and fixed view-switching logic.
// V4: Temporarily hid TabBar for a more focused view.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:kitchen_organizer_app/screens/kitchen/staff_home_screen.dart';
import 'package:kitchen_organizer_app/screens/kitchen/staff_inventory_count_screen.dart';
import 'package:kitchen_organizer_app/providers.dart';
import 'package:kitchen_organizer_app/widgets/notification_bell_widget.dart';
import 'package:kitchen_organizer_app/screens/user/edit_profile_screen.dart';

class StaffWrapperScreen extends ConsumerWidget {
  const StaffWrapperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider).value;

    // return DefaultTabController(
    //   length: 2, // We have two tabs: Today and Inventory
    //   child: 
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('The Pass'),
          actions: [
            // Button to reset the date to today
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () {
                ref.read(selectedDateProvider.notifier).state = DateTime.now();
              },
              tooltip: 'Go to Today',
            ),
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
          // Hiding the TabBar for now.
          // bottom: const TabBar(
          //   tabs: [
          //     Tab(icon: Icon(Icons.today), text: 'Today'),
          //     Tab(icon: Icon(Icons.inventory), text: 'Inventory'),
          //   ],
          // ),
        ),
        // Displaying only the StaffHomeScreen instead of the TabBarView
        body: const StaffHomeScreen(),
        // body: const TabBarView(
        //   children: [
        //     // Page 1: The main staff dashboard
        //     const StaffHomeScreen(),
        //     // Page 2: The inventory counting screen
        //     StaffInventoryCountScreen(),
        //   ],
        // ),
      );
    // );
  }
}

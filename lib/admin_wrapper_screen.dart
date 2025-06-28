import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'; // Required for SystemNavigator

import 'admin_home_screen.dart';
import 'staff_wrapper_screen.dart'; // This is the screen for general staff functionality
import 'floor_staff_dashboard_screen.dart'; // The new floor staff specific screen
import 'providers.dart'; // To access appUserProvider for role and logout

class AdminWrapperScreen extends ConsumerStatefulWidget {
  const AdminWrapperScreen({super.key});

  @override
  ConsumerState<AdminWrapperScreen> createState() => _AdminWrapperScreenState();
}

class _AdminWrapperScreenState extends ConsumerState<AdminWrapperScreen> {
  int _selectedIndex = 0; // State to manage the currently selected tab

  // List of pages/dashboards accessible by Admin
  late final List<Widget> _adminPages;

  @override
  void initState() {
    super.initState();
    // Initialize the list of pages.
    // Note: AdminHomeScreen and StaffWrapperScreen's `onToggleView` will be null or handle internal logic
    // as navigation is now managed by this wrapper's BottomNavigationBar.
    _adminPages = [
      // Admin Dashboard - passing null for onToggleView as it's handled by this wrapper
      const AdminHomeScreen(onToggleView: null),
      // Staff Wrapper Screen - passing null for onToggleView as it's handled by this wrapper
      const StaffWrapperScreen(onToggleView: null),
      // Floor Staff Dashboard Screen
      const FloorStaffDashboardScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserProvider).value; // Get current user for logout action

    return PopScope(
      canPop: false, // Prevents default back button behavior
      onPopInvoked: (bool didPop) async {
        if (didPop) return; // If pop was already handled, do nothing

        final bool? shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Exit App?'),
              content: const Text('Are you sure you want to close the app?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('No'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: const Text('Yes'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        );

        if (shouldPop ?? false) {
          SystemNavigator.pop(); // Close the app if confirmed
        }
      },
      child: Scaffold(
        // AppBar will be dynamically controlled by child screens if they have their own AppBars.
        // For simplicity, we're assuming children manage their own AppBars.
        // If children don't have AppBars, you might add one here.
        body: IndexedStack(
          index: _selectedIndex,
          children: _adminPages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              label: 'Admin',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline), // Or a more specific staff icon
              label: 'Staff',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.room_service_outlined), // Icon for floor staff
              label: 'Floor',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed, // Labels always visible
          backgroundColor: Colors.white, // Ensure bottom nav background is clear
        ),
      ),
    );
  }
}

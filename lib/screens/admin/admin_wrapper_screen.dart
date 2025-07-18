// lib/admin_wrapper_screen.dart
// UPDATED: Added Butcher dashboard to the main navigation bar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'package:kitchen_organizer_app/screens/admin/admin_home_screen.dart';
import 'package:kitchen_organizer_app/screens/kitchen/staff_wrapper_screen.dart';
import 'package:kitchen_organizer_app/screens/floor/floor_staff_dashboard_screen.dart';
import 'package:kitchen_organizer_app/screens/butcher/butcher_dashboard_screen.dart'; // <-- NEW IMPORT

class AdminWrapperScreen extends ConsumerStatefulWidget {
  const AdminWrapperScreen({super.key});

  @override
  ConsumerState<AdminWrapperScreen> createState() => _AdminWrapperScreenState();
}

class _AdminWrapperScreenState extends ConsumerState<AdminWrapperScreen> {
  int _selectedIndex = 0;

  // UPDATED: Added the ButcherDashboardScreen to the list of pages.
  late final List<Widget> _adminPages;

  @override
  void initState() {
    super.initState();
    _adminPages = [
      const AdminHomeScreen(),
      const StaffWrapperScreen(),
      const FloorStaffDashboardScreen(),
      const ButcherDashboardScreen(), // <-- NEW PAGE
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        showDialog<bool>(
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
        ).then((shouldPop) {
          if (shouldPop ?? false) {
            SystemNavigator.pop();
          }
        });
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _adminPages,
        ),
        // UPDATED: Added the new Butcher navigation item.
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              label: 'Admin',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.soup_kitchen_outlined),
              label: 'Kitchen',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.deck_outlined),
              label: 'Floor',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.set_meal_outlined), // <-- NEW ICON
              label: 'Butcher', // <-- NEW LABEL
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}
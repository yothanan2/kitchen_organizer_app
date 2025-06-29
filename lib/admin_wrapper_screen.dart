// lib/admin_wrapper_screen.dart
// CORRECTED: Updated PopScope to resolve deprecation warning.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'admin_home_screen.dart';
import 'staff_wrapper_screen.dart';
import 'floor_staff_dashboard_screen.dart';
import 'providers.dart';

class AdminWrapperScreen extends ConsumerStatefulWidget {
  const AdminWrapperScreen({super.key});

  @override
  ConsumerState<AdminWrapperScreen> createState() => _AdminWrapperScreenState();
}

class _AdminWrapperScreenState extends ConsumerState<AdminWrapperScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _adminPages;

  @override
  void initState() {
    super.initState();
    _adminPages = [
      const AdminHomeScreen(onToggleView: null),
      const StaffWrapperScreen(onToggleView: null),
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
    return PopScope(
      canPop: false,
      // UPDATED: This now correctly handles the async dialog without making the callback async.
      onPopInvoked: (bool didPop) {
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
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              label: 'Admin',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              label: 'Staff',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.room_service_outlined),
              label: 'Floor',
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
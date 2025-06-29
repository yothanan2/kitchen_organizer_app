// lib/staff_wrapper_screen.dart
// CORRECTED: Updated PopScope to resolve deprecation warning.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'staff_home_screen.dart';
import 'staff_inventory_count_screen.dart';

class StaffWrapperScreen extends StatefulWidget {
  final String? userRole;
  final VoidCallback? onToggleView;

  const StaffWrapperScreen({super.key, this.userRole, this.onToggleView});

  @override
  State<StaffWrapperScreen> createState() => _StaffWrapperScreenState();
}

class _StaffWrapperScreenState extends State<StaffWrapperScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      StaffHomeScreen(userRole: widget.userRole, onToggleView: widget.onToggleView),
      const StaffInventoryCountScreen(),
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
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.today_outlined),
              label: 'Today',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              label: 'Inventory',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}
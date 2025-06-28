// lib/home_screen.dart
// THIS FILE IS TEMPORARILY MODIFIED.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_home_screen.dart';
import 'staff_wrapper_screen.dart';
import 'providers.dart'; // Import our central providers file

// A provider to manage the state of the view toggle (Admin vs. Staff)
final isViewingAsStaffProvider = StateProvider<bool>((ref) {
  // Read the user's role and set the initial state.
  final userRole = ref.watch(appUserProvider).value?.role;
  return userRole == 'Staff';
});

// The HomeScreen is now a clean ConsumerWidget.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch our central provider for the current user's data.
    final appUser = ref.watch(appUserProvider).value;

    // Watch the new state provider for the view toggle.
    final isViewingAsStaff = ref.watch(isViewingAsStaffProvider);

    // If there's no user data yet, show a loading screen.
    if (appUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // The logic to show the correct screen is now much simpler.
    if (isViewingAsStaff) {
      return StaffWrapperScreen(
        userRole: appUser.role,
        // The toggle now just updates the state provider.
        onToggleView: appUser.role == 'Admin'
            ? () => ref.read(isViewingAsStaffProvider.notifier).state = false
            : null,
      );
    } else {
      // TEMPORARY FIX: Removed the onToggleView parameter to allow compilation
      // with the simplified admin_home_screen.
      return const AdminHomeScreen();
    }
  }
}
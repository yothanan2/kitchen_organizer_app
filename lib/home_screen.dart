// lib/home_screen.dart
// V2: Correctly calls StaffWrapperScreen without parameters.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_home_screen.dart';
import 'staff_wrapper_screen.dart';
import 'providers.dart';

// This provider manages whether an Admin is viewing the Staff or Admin dashboard.
final isViewingAsStaffProvider = StateProvider<bool>((ref) {
  final userRole = ref.watch(appUserProvider).value?.role;
  // Default to staff view unless the user is an Admin, then default to admin view.
  return userRole != 'Admin';
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider).value;
    final isViewingAsStaff = ref.watch(isViewingAsStaffProvider);

    if (appUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (isViewingAsStaff) {
      // The wrapper screen is now self-contained and doesn't need parameters.
      return const StaffWrapperScreen();
    } else {
      // The Admin screen still needs a way to toggle back to the staff view.
      return AdminHomeScreen(
        onToggleView: () => ref.read(isViewingAsStaffProvider.notifier).state = true,
      );
    }
  }
}
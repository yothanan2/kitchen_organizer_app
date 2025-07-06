// lib/screens/kitchen/kitchen_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchen_organizer_app/screens/admin/admin_home_screen.dart';
import 'package:kitchen_organizer_app/screens/kitchen/staff_home_screen.dart';
import 'package:kitchen_organizer_app/providers.dart';
import 'package:kitchen_organizer_app/screens/user/edit_profile_screen.dart';

class KitchenDashboardScreen extends ConsumerWidget {
  const KitchenDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider).value;
    final isViewingAsStaff = ref.watch(isViewingAsStaffProvider);

    if (appUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Widget currentScreen;
    if (isViewingAsStaff) {
      currentScreen = const StaffHomeScreen();
    } else {
      currentScreen = AdminHomeScreen(
        onToggleView: () => ref.read(isViewingAsStaffProvider.notifier).state = true,
      );
    }

    return Scaffold(
      body: currentScreen,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const EditProfileScreen()),
          );
        },
        child: const Icon(Icons.edit),
      ),
    );
  }
}
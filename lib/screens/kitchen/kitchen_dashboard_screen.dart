import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchen_organizer_app/screens/admin/admin_home_screen.dart';
import 'package:kitchen_organizer_app/screens/kitchen/staff_home_screen.dart';
import 'package:kitchen_organizer_app/screens/kitchen/mise_en_place_screen.dart';
import 'package:kitchen_organizer_app/providers.dart';

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
    if (appUser.role == 'Kitchen Staff') {
      currentScreen = const MiseEnPlaceScreen();
    } else if (appUser.role == 'Admin') {
      if (isViewingAsStaff) {
        currentScreen = const StaffHomeScreen();
      } else {
        currentScreen = AdminHomeScreen(
          onToggleView: () => ref.read(isViewingAsStaffProvider.notifier).state = true,
        );
      }
    } else {
      // Default case or other roles, e.g., redirect to a generic dashboard or error screen
      currentScreen = const Center(child: Text('Unauthorized access or unknown role.'));
    }

    return Scaffold(
      body: currentScreen,
    );
  }
}
// lib/auth_gate.dart
// MODIFIED: Added logic to bypass email verification for known development accounts.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as developer;

import 'login_screen.dart';
import 'verify_email_screen.dart';
import 'pending_approval_screen.dart';
import 'home_screen.dart';
import 'floor_staff_dashboard_screen.dart';
import 'screens/butcher/butcher_dashboard_screen.dart';
import 'admin_wrapper_screen.dart';
import 'staff_wrapper_screen.dart';

import 'providers.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  // --- NEW: A list of developer emails to bypass verification ---
  static const List<String> _devEmails = [
    'yothanan@gmail.com',
    'yothanan.rov@gmail.com',
    'yothanan2@gmail.com',
    'butcher@test.com',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUserAsync = ref.watch(appUserProvider);

    return appUserAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(body: Center(child: Text('An error occurred: $error'))),
      data: (appUser) {
        if (appUser == null) {
          developer.log('AuthGate: User is null, returning LoginScreen.');
          return const LoginScreen();
        }

        // --- MODIFIED: The verification check now ignores dev emails ---
        if (!appUser.isEmailVerified && !_devEmails.contains(appUser.email)) {
          developer.log('AuthGate: User email not verified, returning VerifyEmailScreen.');
          return const VerifyEmailScreen();
        }

        if (!appUser.isApproved) {
          developer.log('AuthGate: User not approved, returning PendingApprovalScreen.');
          return const PendingApprovalScreen();
        }

        developer.log('AuthGate: User role is "${appUser.role}".');
        switch (appUser.role) {
          case 'Admin':
            developer.log('AuthGate: User is Admin, returning AdminWrapperScreen.');
            return const AdminWrapperScreen();
          case 'Floor Staff':
            developer.log('AuthGate: User is Floor Staff, returning FloorStaffDashboardScreen.');
            return const FloorStaffDashboardScreen();
          case 'Butcher':
            developer.log('AuthGate: User is Butcher, returning ButcherDashboardScreen.');
            return const ButcherDashboardScreen();
          case 'Kitchen Staff':
            developer.log('AuthGate: User is Kitchen Staff, returning StaffWrapperScreen.');
            return const StaffWrapperScreen();
          default:
            developer.log('AuthGate: User is Staff (default), returning StaffWrapperScreen.');
            return const StaffWrapperScreen();
        }
      },
    );
  }
}
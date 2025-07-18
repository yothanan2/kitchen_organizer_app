// lib/auth_gate.dart
// FINAL: Corrects all import paths to reflect the project's file structure.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

// --- CORRECTED IMPORTS ---
import 'login_screen.dart';
import 'screens/admin/pending_approval_screen.dart';
import 'verify_email_screen.dart';
import 'screens/admin/admin_wrapper_screen.dart';
import 'screens/kitchen/staff_wrapper_screen.dart';
import 'screens/butcher/butcher_dashboard_screen.dart';
import 'screens/floor/floor_staff_dashboard_screen.dart';
// --- END OF CORRECTIONS ---


class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(firebaseAuthProvider).authStateChanges();

    return StreamBuilder<User?>(
      stream: authState,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final appUserAsync = ref.watch(appUserProvider);

        // Notifications are now handled by the NotificationBellWidget.

        return appUserAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, stack) => Scaffold(body: Center(child: Text('Error loading user data: $err'))),
          data: (appUser) {
            if (appUser == null) {
              return const LoginScreen();
            }
            if (!appUser.isEmailVerified && appUser.role != 'Butcher') {
              return const VerifyEmailScreen();
            }
            if (!appUser.isApproved) {
              return const PendingApprovalScreen();
            }

            // --- ROUTING LOGIC (No changes needed here) ---
            switch (appUser.role) {
              case 'Admin':
                return const AdminWrapperScreen();
              case 'Floor Staff':
                return const FloorStaffDashboardScreen();
              case 'Butcher':
                return const ButcherDashboardScreen();
              case 'Kitchen Staff':
                return const StaffWrapperScreen();
              default:
              // Fallback for unassigned roles
                return const StaffWrapperScreen();
            }
          },
        );
      },
    );
  }
}
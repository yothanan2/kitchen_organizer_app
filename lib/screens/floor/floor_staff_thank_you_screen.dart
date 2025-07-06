// lib/floor_staff_thank_you_screen.dart
// CORRECTED: Updated PopScope to resolve deprecation warning.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchen_organizer_app/auth_gate.dart';

class FloorStaffThankYouScreen extends ConsumerWidget {
  final String reporterName;

  const FloorStaffThankYouScreen({
    super.key,
    required this.reporterName,
  });

  void _goToDashboard(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthGate()),
          (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      // UPDATED: This now uses the correct signature and logic.
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        _goToDashboard(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Report Sent!'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 100,
                ),
                const SizedBox(height: 24),
                Text(
                  'Thank you, $reporterName!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your stock check has been successfully submitted.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () => _goToDashboard(context),
                  icon: const Icon(Icons.dashboard_outlined),
                  label: const Text('Back to Dashboard'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 50),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
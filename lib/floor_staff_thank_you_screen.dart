import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_gate.dart'; // Import AuthGate for navigation

class FloorStaffThankYouScreen extends ConsumerWidget {
  // The reporter's name is passed in to personalize the message.
  final String reporterName;

  const FloorStaffThankYouScreen({
    super.key,
    required this.reporterName,
  });

  // A helper method to navigate back to the main dashboard.
  void _goToDashboard(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthGate()),
          (Route<dynamic> route) => false, // Clear all previous routes
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The PopScope prevents the user from accidentally swiping back
    // and re-submitting a form. It redirects them to the dashboard.
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        _goToDashboard(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Report Sent!'),
          automaticallyImplyLeading: false, // Hide the default back button
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

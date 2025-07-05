// lib/butcher_dashboard_screen.dart
// FINAL: Adds a "Requisition History" card to the dashboard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'butcher_requisition_screen.dart';
import 'butcher_confirmation_screen.dart';
import 'screens/butcher/butcher_requisition_history_screen.dart'; // <-- IMPORT the new screen
import 'providers.dart';
import 'widgets/weather_card_widget.dart';
import 'widgets/daily_note_card_widget.dart';

class ButcherDashboardScreen extends ConsumerStatefulWidget {
  const ButcherDashboardScreen({super.key});

  @override
  ConsumerState<ButcherDashboardScreen> createState() => _ButcherDashboardScreenState();
}

class _ButcherDashboardScreenState extends ConsumerState<ButcherDashboardScreen> with TickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    }
    if (hour < 17) {
      return 'Good Afternoon';
    }
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final preparedCountAsync = ref.watch(preparedRequisitionsCountProvider);
    final hasPreparedItems = (preparedCountAsync.value ?? 0) > 0;
    final userName = ref.watch(appUserProvider).value?.fullName?.split(' ').first ?? '';

    if (hasPreparedItems) {
      if (!_animationController.isAnimating) {
        _animationController.repeat(reverse: true);
      }
    } else {
      _animationController.stop();
      _animationController.reset();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Butcher Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                '${_getGreeting()}, $userName',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const WeatherCard(),
            const SizedBox(height: 16),
            const DailyNoteCard(noteFieldName: 'forButcherStaff'),
            const SizedBox(height: 16),
            // --- THIS IS THE UPDATED LAYOUT SECTION ---
            LayoutBuilder(
              builder: (context, constraints) {
                // For smaller screens, we stack all cards vertically
                if (constraints.maxWidth < 600) {
                  return Column(
                    children: [
                      _buildDashboardCard(
                        context: context,
                        icon: Icons.add_shopping_cart,
                        title: 'Create New Requisition',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const ButcherRequisitionScreen(),
                        )),
                      ),
                      const SizedBox(height: 16),
                      _buildAnimatedCard(preparedCountAsync),
                      const SizedBox(height: 16), // Spacing
                      // --- NEW HISTORY CARD ---
                      _buildDashboardCard(
                        context: context,
                        icon: Icons.history,
                        title: 'Requisition History',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const ButcherRequisitionHistoryScreen(),
                        )),
                      ),
                    ],
                  );
                } else {
                  // For wider screens, we use a row-based layout
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildDashboardCard(
                              context: context,
                              icon: Icons.add_shopping_cart,
                              title: 'Create New Requisition',
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => const ButcherRequisitionScreen(),
                              )),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: _buildAnimatedCard(preparedCountAsync)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // --- NEW HISTORY CARD (Full Width) ---
                      _buildDashboardCard(
                        context: context,
                        icon: Icons.history,
                        title: 'Requisition History',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const ButcherRequisitionHistoryScreen(),
                        )),
                      ),
                    ],
                  );
                }
              },
            ),
            // --- END OF UPDATED LAYOUT SECTION ---
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCard(AsyncValue<int> preparedCountAsync) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final color = ColorTween(
          begin: Theme.of(context).cardColor,
          end: Colors.amber.shade200,
        ).evaluate(_animationController);

        return _buildDashboardCard(
          context: context,
          icon: Icons.check_circle_outline,
          title: 'Prepared Items Ready for Pickup',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const ButcherConfirmationScreen(),
          )),
          asyncValue: preparedCountAsync,
          cardColor: color,
        );
      },
    );
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    AsyncValue<int>? asyncValue,
    Color? cardColor,
  }) {
    return SizedBox(
      height: 180,
      child: Card(
        color: cardColor,
        elevation: 4,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (asyncValue != null)
                  asyncValue.when(
                    loading: () => const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (err, stack) => const Icon(Icons.error_outline, color: Colors.red, size: 24),
                    data: (count) {
                      if (count > 0) {
                        return CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.amber.shade800,
                          child: Text(
                            count.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        );
                      }
                      return const SizedBox(height: 24);
                    },
                  )
                else
                  const SizedBox(height: 24),
                const Spacer(),
                Icon(icon, size: 48, color: Theme.of(context).primaryColor),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
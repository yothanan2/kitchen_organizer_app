// lib/widgets/notification_bell_widget.dart
// FINAL: Added blinking animation controlled by the hasOpenRequestsProvider.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers.dart';

// Provider for the unread notification count remains the same.
final unreadNotificationsProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final user = ref.watch(appUserProvider).value;

  if (user == null) {
    return const Stream.empty();
  }

  return firestore
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .where('isRead', isEqualTo: false)
      .snapshots();
});


class NotificationBellWidget extends ConsumerStatefulWidget {
  const NotificationBellWidget({super.key});

  @override
  ConsumerState<NotificationBellWidget> createState() => _NotificationBellWidgetState();
}

class _NotificationBellWidgetState extends ConsumerState<NotificationBellWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(unreadNotificationsProvider);
    final hasOpenRequests = ref.watch(hasOpenRequestsProvider).value ?? false;

    // Control the animation based on whether there are open requests.
    if (hasOpenRequests) {
      _animationController.repeat(reverse: true);
    } else {
      _animationController.stop();
      _animationController.reset();
    }

    return notificationsAsync.when(
      loading: () => _buildIcon(null),
      error: (err, stack) => _buildIcon(null),
      data: (snapshot) {
        final count = snapshot.docs.length;
        return _buildIcon(count > 0 ? count : null, hasOpenRequests);
      },
    );
  }

  Widget _buildIcon(int? count, [bool isBlinking = false]) {
    final defaultColor = Theme.of(context).appBarTheme.iconTheme?.color ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // If blinking, alternate between red and the default color. Otherwise, just use the default.
        final iconColor = isBlinking && _animationController.value > 0.5 ? Colors.red : defaultColor;
        return Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications, color: iconColor),
              onPressed: () {
                // Future functionality to show notifications can go here.
              },
              tooltip: 'Notifications',
            ),
            if (count != null && count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
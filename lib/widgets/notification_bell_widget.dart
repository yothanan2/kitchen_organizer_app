// lib/widgets/notification_bell_widget.dart
// FINAL: Implements the three-stage (Red/Yellow) blinking logic.

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
    // Watch the new status provider
    final requisitionStatus = ref.watch(openRequisitionStatusProvider).value ?? RequisitionStatus.none;

    // Control the animation based on the requisition status.
    if (requisitionStatus == RequisitionStatus.requested || requisitionStatus == RequisitionStatus.prepared) {
      if (!_animationController.isAnimating) {
        _animationController.repeat(reverse: true);
      }
    } else {
      _animationController.stop();
      _animationController.reset();
    }

    return notificationsAsync.when(
      loading: () => _buildIcon(null, requisitionStatus),
      error: (err, stack) => _buildIcon(null, requisitionStatus),
      data: (snapshot) {
        final count = snapshot.docs.length;
        return _buildIcon(count > 0 ? count : null, requisitionStatus);
      },
    );
  }

  Widget _buildIcon(int? count, RequisitionStatus status) {
    final defaultColor = Theme.of(context).appBarTheme.iconTheme?.color ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        Color iconColor;
        if (status == RequisitionStatus.none) {
          iconColor = defaultColor;
        } else {
          // Determine color based on status and animate
          final targetColor = status == RequisitionStatus.requested ? Colors.red : Colors.amber.shade700;
          iconColor = Color.lerp(defaultColor, targetColor, _animationController.value)!;
        }

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
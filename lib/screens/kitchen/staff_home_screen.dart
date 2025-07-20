// lib/staff_home_screen.dart
// FINAL: Adds a metric card for the new requisition system.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:kitchen_organizer_app/providers.dart';
import 'package:kitchen_organizer_app/widgets/weather_card_widget.dart';
import 'package:kitchen_organizer_app/widgets/daily_note_card_widget.dart';
import 'package:kitchen_organizer_app/screens/kitchen/kitchen_requisition_screen.dart' as k_req_screen;
import 'package:kitchen_organizer_app/screens/kitchen/staff_low_stock_screen.dart';
import 'package:kitchen_organizer_app/screens/kitchen/todays_prep_screen.dart';
import 'package:kitchen_organizer_app/screens/kitchen/mise_en_place_screen.dart';


class StaffHomeScreen extends ConsumerStatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  ConsumerState<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends ConsumerState<StaffHomeScreen> {

  @override
  Widget build(BuildContext context) {
    final String selectedDateString = DateFormat('yyyy-MM-dd').format(ref.watch(selectedDateProvider));
    final lowStockItemsCount = ref.watch(lowStockItemsCountProvider);
    final openRequisitionsCount = ref.watch(openRequisitionsCountProvider);
    final newBarRequestsAsync = ref.watch(newBarRequestsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildNewBarRequests(newBarRequestsAsync, ref, context),
          const WeatherCard(),
          const SizedBox(height: 16),
          const DailyNoteCard(noteFieldName: 'forKitchenStaff'),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              final cards = [
                _buildMetricCard(
                  title: 'Mise en Place',
                  icon: Icons.list_alt_outlined,
                  asyncValue: ref.watch(prepTasksCountProvider(selectedDateString)), // This count might need adjustment later
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MiseEnPlaceScreen())),
                ),
                _buildMetricCard(
                  title: "Today's Preps",
                  icon: Icons.kitchen_outlined,
                  asyncValue: ref.watch(flaggedTasksForTodayCountProvider),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const TodaysPrepScreen())),
                ),
                _buildMetricCard(
                  title: 'Open Requisitions',
                  icon: Icons.assignment_turned_in_outlined,
                  asyncValue: openRequisitionsCount,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const k_req_screen.KitchenRequisitionScreen())),
                ),
                _buildMetricCard(
                  title: 'Low-Stock Items',
                  icon: Icons.warning_amber_rounded,
                  asyncValue: lowStockItemsCount,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const StaffLowStockScreen())),
                ),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: cards.map((card) => Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: card,
                  ))).toList(),
                );
              } else {
                return Column(
                  children: cards.map((card) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: card,
                  )).toList(),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required IconData icon,
    required AsyncValue<int> asyncValue,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
          child: Row(
            children: [
              Icon(icon, size: 32, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              asyncValue.when(
                loading: () => const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (err, stack) => Icon(Icons.error_outline, color: Colors.red.shade700),
                data: (itemCount) {
                  if (itemCount == 0) {
                    return const Icon(Icons.check_circle_outline, color: Colors.green, size: 24);
                  }
                  return CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.orange.shade800,
                    child: Text(
                      itemCount.toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildNewBarRequests(AsyncValue<List<DocumentSnapshot>> newBarRequestsAsync, WidgetRef ref, BuildContext context) {
  return newBarRequestsAsync.when(
    loading: () => const SizedBox.shrink(),
    error: (err, stack) => Text('Error loading new bar requests: ${err.toString()}'),
    data: (requests) {
      if (requests.isEmpty) return const SizedBox.shrink();
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: Colors.blue.shade800,
        elevation: 8,
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Text('New Bar Requests', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          leading: Stack(
            children: [
              const Icon(Icons.notifications, color: Colors.white),
              if (requests.isNotEmpty)
                Positioned(
                  right: 0,
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
                      '${requests.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          children: requests.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String taskName = data['taskName'] ?? 'Unnamed Request';
            final String reportedBy = data['reportedBy'] ?? 'Unknown';
            final String reportedAt = data['createdAt'] != null ? DateFormat('MMM d, hh:mm a').format((data['createdAt'] as Timestamp).toDate()) : '';
            return ListTile(
              tileColor: Colors.white.withAlpha(230),
              title: Text(taskName),
              subtitle: Text('Requested by $reportedBy at $reportedAt'),
              trailing: IconButton(
                icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                onPressed: () => _toggleTaskCompletion(doc, ref, context),
                tooltip: 'Mark as Reviewed',
              ),
            );
          }).toList(),
        ),
      );
    },
  );
}

Future<void> _toggleTaskCompletion(DocumentSnapshot taskDoc, WidgetRef ref, BuildContext context) async {
  final bool currentStatus = taskDoc['isCompleted'] ?? false;
  final currentUser = ref.read(appUserProvider).value;
  final String? completedBy = currentUser?.fullName?.split(' ').first;
  Map<String, dynamic> updateData = {'isCompleted': !currentStatus};
  if (!currentStatus) {
    updateData['completedAt'] = FieldValue.serverTimestamp();
    updateData['completedBy'] = completedBy ?? 'Unknown';
  } else {
    updateData['completedAt'] = FieldValue.delete();
    updateData['completedBy'] = FieldValue.delete();
  }
  try {
    await taskDoc.reference.update(updateData);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to update task: $e'), backgroundColor: Colors.red),
    );
  }
}
// lib/staff_home_screen.dart
// FINAL: Adds a metric card for the new requisition system.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:kitchen_organizer_app/screens/admin/preparation_screen.dart';

import 'package:kitchen_organizer_app/providers.dart';
import 'package:kitchen_organizer_app/widgets/weather_card_widget.dart';
import 'package:kitchen_organizer_app/widgets/daily_note_card_widget.dart';
import 'package:kitchen_organizer_app/screens/kitchen/staff_low_stock_screen.dart';
import 'package:kitchen_organizer_app/screens/kitchen/kitchen_requisition_screen.dart';


class StaffHomeScreen extends ConsumerStatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  ConsumerState<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends ConsumerState<StaffHomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: Colors.red.shade700,
      end: Colors.orange.shade700,
    ).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime currentSelectedDate = ref.read(selectedDateProvider);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentSelectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != currentSelectedDate) {
      ref.read(selectedDateProvider.notifier).state = picked;
    }
  }

  Future<void> _toggleTaskCompletion(DocumentSnapshot taskDoc) async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update task: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime selectedDate = ref.watch(selectedDateProvider);
    final String selectedDateString = DateFormat('yyyy-MM-dd').format(selectedDate);

    final lowStockItemsCount = ref.watch(lowStockItemsCountProvider);
    final openRequisitionsCount = ref.watch(openRequisitionsCountProvider); // <-- Watch new provider
    final isTodaysListGenerated = ref.watch(todaysListExistsProvider(selectedDateString));
    final showCompleted = ref.watch(showCompletedTasksProvider);
    final prepTasksAsync = ref.watch(tasksStreamProvider(TaskListParams(collectionPath: 'prepTasks', isCompleted: false, date: selectedDateString)));
    final completedPrepTasksAsync = ref.watch(tasksStreamProvider(TaskListParams(collectionPath: 'prepTasks', isCompleted: true, date: selectedDateString)));
    final newBarRequestsAsync = ref.watch(newBarRequestsProvider);
    final unitsMapAsync = ref.watch(unitsMapProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildNewBarRequests(newBarRequestsAsync),
          const WeatherCard(),
          const SizedBox(height: 16),
          const DailyNoteCard(noteFieldName: 'forKitchenStaff'),
          const SizedBox(height: 16),
          // --- NEW METRIC CARD ---
          _buildMetricCard(
            context: context,
            title: 'Open Requisitions',
            icon: Icons.assignment_turned_in_outlined,
            asyncValue: openRequisitionsCount,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const KitchenRequisitionScreen())),
          ),
          const SizedBox(height: 16),
          _buildMetricCard(
            context: context,
            title: 'Low-Stock Items',
            icon: Icons.warning_amber_rounded,
            asyncValue: lowStockItemsCount,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const StaffLowStockScreen())),
          ),
          const SizedBox(height: 16),
          _buildDateSelector(context, selectedDate),
          const SizedBox(height: 16),
          // --- OLD REQUISITION LIST REMOVED ---
          _buildPrepListSection(isTodaysListGenerated, context, prepTasksAsync, showCompleted, completedPrepTasksAsync, unitsMapAsync, selectedDate),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required AsyncValue<int> asyncValue,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Theme.of(context).primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              asyncValue.when(
                loading: () => const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                error: (err, stack) => Icon(Icons.error_outline, color: Colors.red.shade700),
                data: (count) {
                  if (count == 0) {
                    return const Icon(Icons.check_circle_outline, color: Colors.green, size: 30);
                  }
                  return CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.orange.shade800,
                    child: Text(
                      count.toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context, DateTime selectedDate) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: ListTile(
        leading: const Icon(Icons.calendar_today),
        title: Text(
          "Viewing Prep Tasks For: ${DateFormat('EEEE, MMM d').format(selectedDate)}",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.arrow_drop_down),
        onTap: () => _selectDate(context),
      ),
    );
  }

  Widget _buildNewBarRequests(AsyncValue<List<DocumentSnapshot>> newBarRequestsAsync) {
    return newBarRequestsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => Text('Error loading new bar requests: ${err.toString()}'),
      data: (requests) {
        if (requests.isEmpty) return const SizedBox.shrink();
        return AnimatedBuilder(
          animation: _colorAnimation,
          builder: (context, child) {
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              color: _colorAnimation.value,
              elevation: 8,
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text('New Bar Requests (${requests.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                leading: const Icon(Icons.notifications_active_outlined, color: Colors.white),
                children: requests.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String taskName = data['taskName'] ?? 'Unnamed Request';
                  final String reportedBy = data['reportedBy'] ?? 'Unknown';
                  final String reportedAt = data['createdAt'] != null ? DateFormat('MMM d, hh:mm a').format((data['createdAt'] as Timestamp).toDate()) : '';
                  return ListTile(
                    tileColor: Colors.white.withOpacity(0.9),
                    title: Text(taskName),
                    subtitle: Text('Requested by $reportedBy at $reportedAt'),
                    trailing: IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                      onPressed: () => _toggleTaskCompletion(doc),
                      tooltip: 'Mark as Reviewed',
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPrepListSection(
      AsyncValue<bool> isTodaysListGenerated,
      BuildContext context,
      AsyncValue<QuerySnapshot> prepTasksAsync,
      bool showCompleted,
      AsyncValue<QuerySnapshot> completedPrepTasksAsync,
      AsyncValue<Map<String, String>> unitsMapAsync,
      DateTime selectedDate) {
    return isTodaysListGenerated.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error: ${err.toString()}'),
      data: (exists) {
        if (!exists && selectedDate.isAtSameMomentAs(DateTime.now().toLocal().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0))) {
          return Card(
            color: Colors.blue.shade50,
            margin: const EdgeInsets.only(top: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('No prep list generated for ${DateFormat('EEEE, MMM d').format(selectedDate)}.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PreparationScreen())),
                    icon: const Icon(Icons.add_task),
                    label: const Text('Generate Prep List'),
                  ),
                ],
              ),
            ),
          );
        }

        final prepTasksAsListOfDocs = prepTasksAsync.whenData((qs) => qs.docs);
        final completedPrepTasksAsListOfDocs = completedPrepTasksAsync.whenData((qs) => qs.docs);

        return Column(
          children: [
            _buildTasksSection(context, title: 'Prep Tasks for ${DateFormat('MMM d').format(selectedDate)}', tasksAsync: prepTasksAsListOfDocs, onToggle: _toggleTaskCompletion, isEmptyMessage: 'No prep tasks for this date.', unitsMapAsync: unitsMapAsync),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Show Completed Tasks:', style: TextStyle(fontSize: 16)),
                Switch(value: showCompleted, onChanged: (value) => ref.read(showCompletedTasksProvider.notifier).state = value),
              ],
            ),
            if (showCompleted) ...[
              const SizedBox(height: 20),
              _buildTasksSection(context, title: 'Completed Prep Tasks', tasksAsync: completedPrepTasksAsListOfDocs, onToggle: _toggleTaskCompletion, isEmptyMessage: 'No completed prep tasks for this date.', unitsMapAsync: unitsMapAsync),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTasksSection(BuildContext context, {required String title, required AsyncValue<List<DocumentSnapshot>> tasksAsync, required Future<void> Function(DocumentSnapshot) onToggle, required String isEmptyMessage, bool isButcherRequisition = false, required AsyncValue<Map<String, String>> unitsMapAsync}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 10),
        tasksAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (err, stack) => Text('Error: ${err.toString()}'),
          data: (docs) {
            if (docs.isEmpty) {
              return Center(
                child: Text(isEmptyMessage, style: const TextStyle(fontStyle: FontStyle.italic)),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final taskDoc = docs[index];
                final taskData = taskDoc.data() as Map<String, dynamic>;
                final String taskName = taskData['taskName'] ?? 'Unnamed Task';
                final bool isCompleted = taskData['isCompleted'] ?? false;
                final String? completedBy = taskData['completedBy'];
                final Timestamp? createdAt = taskData['createdAt'];
                String completionInfo = '';
                if (isCompleted && completedBy != null && createdAt != null) {
                  final formattedTime = DateFormat('hh:mm a, MMM d').format(createdAt.toDate());
                  completionInfo = 'Completed by $completedBy at $formattedTime';
                }

                String subtitleText = '';
                if (isButcherRequisition) {
                  final quantity = taskData['quantity']?.toString() ?? 'N/A';
                  final unitRef = taskData['unitRef'] as DocumentReference?;
                  final requestedBy = taskData['requestedBy'] as String? ?? 'Unknown';
                  String unitName = 'Unit';
                  if (unitsMapAsync.hasValue && unitRef != null) {
                    unitName = unitsMapAsync.value![unitRef.id] ?? 'Unit';
                  }
                  subtitleText = 'Quantity: $quantity $unitName - Requested by $requestedBy';
                  if (isCompleted && completionInfo.isNotEmpty) {
                    subtitleText += '\n$completionInfo';
                  } else if (createdAt != null) {
                    subtitleText += '\nRequested on ${DateFormat('MMM d').format(createdAt.toDate())}';
                  }
                } else if (isCompleted && completionInfo.isNotEmpty) {
                  subtitleText = completionInfo;
                }

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: CheckboxListTile(
                    title: Text(taskName, style: TextStyle(decoration: isCompleted ? TextDecoration.lineThrough : TextDecoration.none, color: isCompleted ? Colors.grey : Colors.black87)),
                    subtitle: subtitleText.isNotEmpty ? Text(subtitleText, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)) : null,
                    value: isCompleted,
                    onChanged: (bool? newValue) => onToggle(taskDoc),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
// lib/floor_staff_dashboard_screen.dart
// FINAL CORRECTION: Restored the correct navigation logic to the correct screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'providers.dart';
import 'floor_staff_confirmation_screen.dart'; // Correct import
import 'widgets/weather_card_widget.dart';
import 'widgets/daily_note_card_widget.dart';

class FloorChecklistItem {
  final String id;
  final String name;
  FloorChecklistItem({required this.id, required this.name});
  factory FloorChecklistItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FloorChecklistItem(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Item',
    );
  }
}

final floorChecklistItemsStreamProvider = StreamProvider.autoDispose<List<FloorChecklistItem>>((ref) {
  return ref.watch(firestoreProvider)
      .collection('floor_checklist_items')
      .orderBy('order')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => FloorChecklistItem.fromFirestore(doc)).toList());
});


class FloorStaffDashboardScreen extends ConsumerStatefulWidget {
  const FloorStaffDashboardScreen({super.key});

  @override
  ConsumerState<FloorStaffDashboardScreen> createState() => _FloorStaffDashboardScreenState();
}

class _FloorStaffDashboardScreenState extends ConsumerState<FloorStaffDashboardScreen> with SingleTickerProviderStateMixin {
  final Set<String> _selectedForReportingIds = {};
  bool _isSending = false;
  late AnimationController _blinkAnimationController;
  Timer? _timeCheckTimer;

  @override
  void initState() {
    super.initState();
    _blinkAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setupTimeCheckTimer();
        _syncPreviouslyReportedItems();
      }
    });
  }

  void _syncPreviouslyReportedItems() {
    final tomorrowsReportedItemsAsync = ref.read(tomorrowsFloorStaffPrepTasksProvider);
    tomorrowsReportedItemsAsync.whenData((previouslyReportedIds) {
      if (mounted) {
        setState(() {
          _selectedForReportingIds.addAll(previouslyReportedIds);
        });
      }
    });
  }

  @override
  void dispose() {
    _blinkAnimationController.dispose();
    _timeCheckTimer?.cancel();
    super.dispose();
  }

  void _setupTimeCheckTimer() {
    _timeCheckTimer?.cancel();
    final now = DateTime.now();
    DateTime tenPmToday = DateTime(now.year, now.month, now.day, 22);

    void updateBlinkingState() {
      if (!mounted) return;
      final shouldBlink = _getShouldButtonBlink(ref.read(tomorrowsFloorStaffPrepTasksProvider));
      if (shouldBlink) {
        if (!_blinkAnimationController.isAnimating) {
          _blinkAnimationController.repeat(reverse: true);
        }
      } else {
        if (_blinkAnimationController.isAnimating) {
          _blinkAnimationController.stop();
          _blinkAnimationController.value = 0;
        }
      }
      if(mounted) setState(() {});
    }

    updateBlinkingState();
    DateTime nextTenPm = now.isAfter(tenPmToday) ? tenPmToday.add(const Duration(days: 1)) : tenPmToday;
    _timeCheckTimer = Timer(nextTenPm.difference(now), () {
      updateBlinkingState();
      _setupTimeCheckTimer();
    });
  }

  bool _getShouldButtonBlink(AsyncValue<Set<String>> tomorrowsItems) {
    return DateTime.now().hour >= 22 && (tomorrowsItems.valueOrNull?.isEmpty ?? true);
  }

  // --- THIS IS THE CORRECTED METHOD ---
  void _navigateToConfirmationScreen() async {
    final itemsToActuallyReport = _selectedForReportingIds.toSet();
    final alreadyReported = ref.read(tomorrowsFloorStaffPrepTasksProvider).value ?? {};
    itemsToActuallyReport.removeAll(alreadyReported);

    if (itemsToActuallyReport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select new items to report, or all items have already been reported.'), backgroundColor: Colors.blue),
      );
      return;
    }

    setState(() { _isSending = true; });

    // The 'reportDate' is now used again.
    final reportDate = DateTime.now().add(const Duration(days: 1));

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          // Navigating to the correct screen with the correct parameters.
          builder: (context) => FloorStaffConfirmationScreen(
            selectedItemIds: itemsToActuallyReport,
            reportDate: reportDate,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _selectedForReportingIds.clear();
        });
        ref.invalidate(tomorrowsFloorStaffPrepTasksProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserProvider).value;
    final reporterDisplayName = appUser?.fullName?.split(' ').first ?? 'Staff';
    final tomorrowsReportedItemsAsync = ref.watch(tomorrowsFloorStaffPrepTasksProvider);
    final shouldBlink = _getShouldButtonBlink(tomorrowsReportedItemsAsync);

    final Animation<Color?> buttonBlinkColorAnimation = ColorTween(
      begin: Colors.red.shade700,
      end: Theme.of(context).primaryColor.withOpacity(0.7),
    ).animate(_blinkAnimationController);

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $reporterDisplayName!'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(floorChecklistItemsStreamProvider);
          ref.invalidate(tomorrowsFloorStaffPrepTasksProvider);
          ref.invalidate(weatherProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    const WeatherCard(),
                    const SizedBox(height: 16),
                    const DailyNoteCard(noteFieldName: 'forFloorStaff'),
                    const _KitchenNoteCard(),
                    _PreviouslyReportedItemsCard(tomorrowsItems: tomorrowsReportedItemsAsync),
                    const Divider(height: 24, indent: 16, endIndent: 16),
                    const Text("Make Urgent Request for Tomorrow", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Text(
                        "Select items below that are running low and need to be prepped for tomorrow's service.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _ChecklistSliver(
              selectedIds: _selectedForReportingIds,
              alreadyReportedIds: tomorrowsReportedItemsAsync.value ?? {},
              onChanged: (id, value) {
                setState(() {
                  if (value) {
                    _selectedForReportingIds.add(id);
                  } else {
                    _selectedForReportingIds.remove(id);
                  }
                });
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AnimatedBuilder(
        animation: _blinkAnimationController,
        builder: (context, child) {
          return FloatingActionButton.extended(
            onPressed: _isSending ? null : _navigateToConfirmationScreen,
            label: _isSending ? const Text('Sending...') : const Text("Send Urgent Request"),
            icon: _isSending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_outlined),
            backgroundColor: shouldBlink ? buttonBlinkColorAnimation.value : Theme.of(context).primaryColor,
          );
        },
      ),
    );
  }
}

class _KitchenNoteCard extends ConsumerWidget {
  const _KitchenNoteCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dailyDocAsync = ref.watch(dailyTodoListDocProvider(dateString));
    return dailyDocAsync.when(
      data: (doc) {
        if (!doc.exists) return const SizedBox.shrink();
        final data = doc.data() as Map<String, dynamic>;

        final note = data['kitchenToFloorNote'] as String?;

        if (note == null || note.trim().isEmpty) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          color: Colors.lightBlue.shade100,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.soup_kitchen_outlined, color: Colors.blue.shade800),
                    const SizedBox(width: 8),
                    Text("Note from the Kitchen", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900)),
                  ],
                ),
                const Divider(height: 16),
                Text(note, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e,s) => const SizedBox.shrink(),
    );
  }
}

class _PreviouslyReportedItemsCard extends ConsumerWidget {
  final AsyncValue<Set<String>> tomorrowsItems;
  const _PreviouslyReportedItemsCard({required this.tomorrowsItems});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allItemsAsync = ref.watch(floorChecklistItemsStreamProvider);
    return tomorrowsItems.when(
      data: (reportedIds) {
        if (reportedIds.isEmpty) return const SizedBox.shrink();
        return allItemsAsync.when(
          data: (allFloorItems) {
            final reportedDetails = allFloorItems.where((item) => reportedIds.contains(item.id)).toList();
            if (reportedDetails.isEmpty) return const SizedBox.shrink();

            return Card(
              margin: const EdgeInsets.fromLTRB(0, 0, 0, 16),
              child: ExpansionTile(
                title: Text('Already Requested for Tomorrow (${reportedDetails.length})'),
                leading: const Icon(Icons.check_circle, color: Colors.green),
                children: reportedDetails.map((item) => ListTile(
                  title: Text(item.name, style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
                  dense: true,
                )).toList(),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (e,s) => const SizedBox.shrink(),
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
      error: (e,s) => const SizedBox.shrink(),
    );
  }
}

class _ChecklistSliver extends ConsumerWidget {
  final Set<String> selectedIds;
  final Set<String> alreadyReportedIds;
  final Function(String, bool) onChanged;

  const _ChecklistSliver({required this.selectedIds, required this.alreadyReportedIds, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(floorChecklistItemsStreamProvider);
    return itemsAsync.when(
      loading: () => const SliverToBoxAdapter(child: Center(child: Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(),
      ))),
      error: (err, stack) => SliverToBoxAdapter(child: Center(child: Text('Error: ${err.toString()}'))),
      data: (items) {
        if (items.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text("No checklist items configured.")),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final item = items[index];
                final isPreviouslyReported = alreadyReportedIds.contains(item.id);
                final isChecked = selectedIds.contains(item.id);

                return Opacity(
                  opacity: isPreviouslyReported ? 0.6 : 1.0,
                  child: Card(
                    elevation: 2,
                    child: CheckboxListTile(
                      title: Text(item.name, style: TextStyle(decoration: isPreviouslyReported ? TextDecoration.lineThrough : TextDecoration.none)),
                      value: isChecked,
                      onChanged: isPreviouslyReported ? null : (value) => onChanged(item.id, value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                );
              },
              childCount: items.length,
            ),
          ),
        );
      },
    );
  }
}
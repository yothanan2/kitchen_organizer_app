// lib/staff_home_screen.dart
// CORRECTED: Updated to use the public 'selectedDateProvider'.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'preparation_screen.dart';
import 'providers.dart';

class StaffHomeScreen extends ConsumerStatefulWidget {
  final String? userRole;
  final VoidCallback? onToggleView;

  const StaffHomeScreen({super.key, this.userRole, this.onToggleView});

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
      end: Colors.green.shade700,
    ).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    // UPDATED to use public provider name
    DateTime currentSelectedDate = ref.read(selectedDateProvider);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentSelectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != currentSelectedDate) {
      // UPDATED to use public provider name
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

  Color _getWeatherCardColor(String weatherDescription) {
    String lowerCaseDesc = weatherDescription.toLowerCase();
    if (lowerCaseDesc.contains('clear') || lowerCaseDesc.contains('sun')) return Colors.amber.shade100;
    if (lowerCaseDesc.contains('cloudy') || lowerCaseDesc.contains('overcast')) return Colors.blueGrey.shade50;
    if (lowerCaseDesc.contains('rain') || lowerCaseDesc.contains('drizzle') || lowerCaseDesc.contains('showers')) return Colors.lightBlue.shade100;
    if (lowerCaseDesc.contains('snow')) return Colors.blue.shade50;
    if (lowerCaseDesc.contains('thunderstorm')) return Colors.indigo.shade100;
    if (lowerCaseDesc.contains('fog')) return Colors.grey.shade200;
    return Colors.grey.shade100;
  }

  Color _getTextColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    // UPDATED to use public provider name
    final DateTime selectedDate = ref.watch(selectedDateProvider);
    final String selectedDateString = DateFormat('yyyy-MM-dd').format(selectedDate);

    final isTodaysListGenerated = ref.watch(todaysListExistsProvider(selectedDateString));
    final showCompleted = ref.watch(showCompletedTasksProvider);
    final prepTasksAsync = ref.watch(tasksStreamProvider(TaskListParams(collectionPath: 'prepTasks', isCompleted: false, date: selectedDateString)));
    final stockReqsAsync = ref.watch(tasksStreamProvider(TaskListParams(collectionPath: 'stockRequisitions', isCompleted: false, date: selectedDateString)));
    final completedPrepTasksAsync = ref.watch(tasksStreamProvider(TaskListParams(collectionPath: 'prepTasks', isCompleted: true, date: selectedDateString)));
    final completedStockReqsAsync = ref.watch(tasksStreamProvider(TaskListParams(collectionPath: 'stockRequisitions', isCompleted: true, date: selectedDateString)));
    final newBarRequestsAsync = ref.watch(newBarRequestsProvider);
    final weatherAsync = ref.watch(weatherProvider);
    final unitsMapAsync = ref.watch(unitsMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        actions: [
          if (widget.userRole == 'Admin' && widget.onToggleView != null)
            Tooltip(
              message: 'Switch to Admin View',
              child: IconButton(icon: const Icon(Icons.switch_account), onPressed: widget.onToggleView),
            ),
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
          children: <Widget>[
            weatherAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Weather Error: ${err.toString()}', style: const TextStyle(color: Colors.red)),
              ),
              data: (weather) {
                Color cardColor = _getWeatherCardColor(weather.dailyWeatherDescription);
                Color textColor = _getTextColor(cardColor);
                final precipitationInfo = weather.findFirstPrecipitation();
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(bottom: 16.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 2, blurRadius: 5, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current: ${weather.currentTemp.toStringAsFixed(1)}°C', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                            Text('${weather.weatherIcon} ${weather.weatherDescription}', style: TextStyle(fontSize: 16, color: textColor)),
                            const SizedBox(height: 8),
                            Text('Today: ${weather.dailyWeatherIcon} ${weather.dailyWeatherDescription}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                            if (precipitationInfo != null) ...[
                              const SizedBox(height: 8),
                              Text('❗️ $precipitationInfo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.9))),
                            ]
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Max: ${weather.maxTemp.toStringAsFixed(1)}°C', style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.7))),
                          Text('Min: ${weather.minTemp.toStringAsFixed(1)}°C', style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.7))),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text("Viewing Tasks For:"),
                subtitle: Text(
                  selectedDate.isAtSameMomentAs(DateTime.now().toLocal().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0))
                      ? 'Today (${DateFormat('EEEE, MMM d').format(selectedDate)})'
                      : DateFormat('EEEE, MMM d, yyyy').format(selectedDate),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () => _selectDate(context),
              ),
            ),
            _DailyNoteCard(selectedDate: selectedDate),
            _KitchenNotesSection(selectedDate: selectedDate),
            newBarRequestsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        backgroundColor: Colors.transparent,
                        collapsedBackgroundColor: Colors.transparent,
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
            ),
            Text(DateFormat('EEEE, MMM d').format(selectedDate), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            isTodaysListGenerated.when(
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => Text('Error: ${err.toString()}'),
              data: (exists) {
                if (!exists) {
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
                return Column(
                  children: [
                    _buildTasksSection(context, title: 'Today\'s Prep Tasks', tasksAsync: prepTasksAsync, onToggle: _toggleTaskCompletion, isEmptyMessage: 'No prep tasks for this date.', unitsMapAsync: unitsMapAsync),
                    const SizedBox(height: 20),
                    _buildTasksSection(context, title: 'What to Bring to the Kitchen', tasksAsync: stockReqsAsync, onToggle: _toggleTaskCompletion, isEmptyMessage: 'No stock requisitions for this date.', isButcherRequisition: true, unitsMapAsync: unitsMapAsync),
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
                      _buildTasksSection(context, title: 'Completed Prep Tasks', tasksAsync: completedPrepTasksAsync, onToggle: _toggleTaskCompletion, isEmptyMessage: 'No completed prep tasks for this date.', unitsMapAsync: unitsMapAsync),
                      const SizedBox(height: 20),
                      _buildTasksSection(context, title: 'Completed Stock Requisitions', tasksAsync: completedStockReqsAsync, onToggle: _toggleTaskCompletion, isEmptyMessage: 'No completed stock requisitions for this date.', isButcherRequisition: true, unitsMapAsync: unitsMapAsync),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksSection(BuildContext context, {required String title, required AsyncValue<QuerySnapshot> tasksAsync, required Future<void> Function(DocumentSnapshot) onToggle, required String isEmptyMessage, bool isButcherRequisition = false, required AsyncValue<Map<String, String>> unitsMapAsync}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        tasksAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (err, stack) => Text('Error: ${err.toString()}'),
          data: (snapshot) {
            if (snapshot.docs.isEmpty) return Text(isEmptyMessage, style: const TextStyle(fontStyle: FontStyle.italic));
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.docs.length,
              itemBuilder: (context, index) {
                final taskDoc = snapshot.docs[index];
                final taskData = taskDoc.data() as Map<String, dynamic>;
                final String taskName = taskData['taskName'] ?? 'Unnamed Task';
                final bool isCompleted = taskData['isCompleted'] ?? false;
                final String? completedBy = taskData['completedBy'];
                final Timestamp? completedAt = taskData['completedAt'];
                String completionInfo = '';
                if (isCompleted && completedBy != null && completedAt != null) {
                  final formattedTime = DateFormat('hh:mm a, MMM d').format(completedAt.toDate());
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
                  }
                } else if (isCompleted && completionInfo.isNotEmpty) {
                  subtitleText = completionInfo;
                }

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  elevation: 2,
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

class _DailyNoteCard extends ConsumerWidget {
  final DateTime selectedDate;
  const _DailyNoteCard({required this.selectedDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // UPDATED to use public provider name
    final String selectedDateString = DateFormat('yyyy-MM-dd').format(selectedDate);
    final dailyDocAsync = ref.watch(dailyTodoListDocProvider(selectedDateString));

    return dailyDocAsync.when(
      data: (doc) {
        if (!doc.exists) return const SizedBox.shrink();
        final data = doc.data() as Map<String, dynamic>;
        final note = data['dailyNotes']?['forKitchenStaff'] as String?;
        if (note == null || note.trim().isEmpty) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          color: Colors.amber.shade100,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.speaker_notes, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    const Text("Admin Note for Today", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color.fromRGBO(102, 62, 3, 1))),
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
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}

class _KitchenNotesSection extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  const _KitchenNotesSection({required this.selectedDate});

  @override
  ConsumerState<_KitchenNotesSection> createState() => __KitchenNotesSectionState();
}

class __KitchenNotesSectionState extends ConsumerState<_KitchenNotesSection> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _floorNoteController = TextEditingController();
  final _butcherNoteController = TextEditingController();
  String _activeFloorNote = '';
  String _activeButcherNote = '';
  bool _isSavingFloor = false;
  bool _isSavingButcher = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNotes();
  }

  @override
  void didUpdateWidget(covariant _KitchenNotesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _loadNotes();
    }
  }

  void _loadNotes() {
    // UPDATED to use public provider name
    final String selectedDateString = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    final dailyDocAsync = ref.read(dailyTodoListDocProvider(selectedDateString));
    dailyDocAsync.whenData((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final currentFloorNote = data['kitchenToFloorNote'] as String? ?? '';
        final currentButcherNote = data['kitchenToButcherNote'] as String? ?? '';
        if (mounted) {
          setState(() {
            _activeFloorNote = currentFloorNote;
            _activeButcherNote = currentButcherNote;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _activeFloorNote = '';
            _activeButcherNote = '';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _floorNoteController.dispose();
    _butcherNoteController.dispose();
    super.dispose();
  }

  Future<void> _saveNote({required String fieldName, required TextEditingController controller}) async {
    final isSavingForFloor = fieldName == 'kitchenToFloorNote';
    setState(() {
      if (isSavingForFloor) _isSavingFloor = true; else _isSavingButcher = true;
    });

    final firestore = ref.read(firestoreProvider);
    final String selectedDateString = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    final note = controller.text.trim();

    try {
      await firestore.collection('dailyTodoLists').doc(selectedDateString).set(
        {fieldName: note},
        SetOptions(merge: true),
      );
      if (mounted) {
        controller.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(note.isEmpty ? "Note cleared!" : "Note sent!"), backgroundColor: Colors.green));
        _loadNotes(); // Reload notes after saving
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving note: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isSavingForFloor) _isSavingFloor = false; else _isSavingButcher = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: const Text("Send Notes to Departments", style: TextStyle(fontWeight: FontWeight.bold)),
        leading: const Icon(Icons.send_and_archive_outlined),
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.deck_outlined), text: 'To Floor'),
              Tab(icon: Icon(Icons.set_meal_outlined), text: 'To Butcher'),
            ],
          ),
          SizedBox(
            height: 250,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNoteTab(
                  controller: _floorNoteController,
                  activeNote: _activeFloorNote,
                  hintText: "e.g., 86 the salmon special",
                  onSave: () => _saveNote(fieldName: 'kitchenToFloorNote', controller: _floorNoteController),
                  isSaving: _isSavingFloor,
                ),
                _buildNoteTab(
                  controller: _butcherNoteController,
                  activeNote: _activeButcherNote,
                  hintText: "e.g., Need 5kg of flank steak for tomorrow",
                  onSave: () => _saveNote(fieldName: 'kitchenToButcherNote', controller: _butcherNoteController),
                  isSaving: _isSavingButcher,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNoteTab({
    required TextEditingController controller,
    required String activeNote,
    required String hintText,
    required VoidCallback onSave,
    required bool isSaving,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (activeNote.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Current Active Note:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(activeNote, style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
          TextField(
            controller: controller,
            maxLines: 2,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: activeNote.isNotEmpty ? "Enter new note to replace..." : "Enter note here...",
              hintText: hintText,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
            label: Text(activeNote.isNotEmpty ? "Update Note" : "Send Note"),
          )
        ],
      ),
    );
  }
}
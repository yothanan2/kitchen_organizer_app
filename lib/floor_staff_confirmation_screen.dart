// lib/floor_staff_confirmation_screen.dart
// CORRECTED: The screen now accepts parameters and handles saving the report to Firestore.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'auth_gate.dart';
import 'providers.dart';

class FloorStaffConfirmationScreen extends ConsumerStatefulWidget {
  // These parameters are now required when navigating to this screen.
  final Set<String> selectedItemIds;
  final DateTime reportDate;

  const FloorStaffConfirmationScreen({
    super.key,
    required this.selectedItemIds,
    required this.reportDate,
  });

  @override
  ConsumerState<FloorStaffConfirmationScreen> createState() => _FloorStaffConfirmationScreenState();
}

class _FloorStaffConfirmationScreenState extends ConsumerState<FloorStaffConfirmationScreen> {
  bool _isSaving = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Save the report as soon as the screen is loaded.
    _saveUrgentReport();
  }

  Future<void> _saveUrgentReport() async {
    final firestore = ref.read(firestoreProvider);
    final appUser = ref.read(appUserProvider).value;
    final reporterName = appUser?.fullName ?? 'Unknown Staff';
    final reportDateString = DateFormat('yyyy-MM-dd').format(widget.reportDate);
    final listDocRef = firestore.collection('dailyTodoLists').doc(reportDateString);

    final batch = firestore.batch();

    // Fetch the names of the checklist items to include in the task name
    final checklistItemsSnapshot = await firestore
        .collection('floor_checklist_items')
        .where(FieldPath.documentId, whereIn: widget.selectedItemIds.toList())
        .get();

    final itemNamesMap = {for (var doc in checklistItemsSnapshot.docs) doc.id: doc['name']};

    for (final itemId in widget.selectedItemIds) {
      final taskName = itemNamesMap[itemId] ?? 'Unknown Item Report';
      final taskRef = listDocRef.collection('prepTasks').doc();
      batch.set(taskRef, {
        'taskName': taskName,
        'category': 'Floor Staff Report', // This category is used by a provider
        'reportedBy': reporterName,
        'createdAt': FieldValue.serverTimestamp(),
        'isCompleted': false,
        'originalFloorChecklistItemId': itemId, // Link back to the original checklist item
      });
    }

    try {
      await batch.commit();
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist Submitted!'),
        automaticallyImplyLeading: false, // No back button
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isSaving
              ? const CircularProgressIndicator() // Show loading indicator while saving
              : _errorMessage != null
              ? _buildErrorState() // Show error message if saving failed
              : _buildSuccessState(), // Show success message once saved
        ),
      ),
    );
  }

  // Widget to show on successful save
  Widget _buildSuccessState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(
          Icons.check_circle_outline,
          color: Colors.green,
          size: 100,
        ),
        const SizedBox(height: 20),
        const Text(
          'Your urgent request has been submitted successfully!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'Thank you for your hard work.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AuthGate()),
                  (Route<dynamic> route) => false,
            );
          },
          icon: const Icon(Icons.home),
          label: const Text('Go to Dashboard'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }

  // Widget to show if there was an error saving
  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, color: Colors.red.shade700, size: 100),
        const SizedBox(height: 20),
        const Text('Failed to Submit', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text('There was an error saving your report: $_errorMessage', textAlign: TextAlign.center),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to Dashboard'),
        ),
      ],
    );
  }
}
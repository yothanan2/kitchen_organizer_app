// lib/butcher_requisition_screen.dart
// FIXED: Corrected a type error when building the units dropdown.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'providers.dart';
import 'models/models.dart';

// Define RequisitionFormData here, as it's specific to this screen
class RequisitionFormData {
  bool isChecked;
  final TextEditingController quantityController;
  DocumentReference? selectedUnitRef; // Now stores a DocumentReference
  RequisitionFormData() : isChecked = false, quantityController = TextEditingController();
}

// This provider now fetches the curated list you created as an admin.
final butcherRequestableItemsProvider = StreamProvider.autoDispose<List<QueryDocumentSnapshot>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('butcher_request_items')
      .orderBy('order')
      .snapshots()
      .map((snapshot) => snapshot.docs);
});


class ButcherRequisitionScreen extends ConsumerStatefulWidget {
  const ButcherRequisitionScreen({super.key});

  @override
  ConsumerState<ButcherRequisitionScreen> createState() => _ButcherRequisitionScreenState();
}

class _ButcherRequisitionScreenState extends ConsumerState<ButcherRequisitionScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  bool _isLoading = false;
  final Map<String, RequisitionFormData> _formState = {};

  @override
  void dispose() {
    for (final data in _formState.values) {
      data.quantityController.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitRequisition() async {
    setState(() => _isLoading = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final List<Map<String, dynamic>> itemsToSubmit = [];

    _formState.forEach((docId, formData) {
      if (formData.isChecked && formData.quantityController.text.isNotEmpty && formData.selectedUnitRef != null) {
        itemsToSubmit.add({
          'itemDocId': docId,
          'quantity': formData.quantityController.text,
          'unitRef': formData.selectedUnitRef!,
        });
      }
    });

    if (itemsToSubmit.isEmpty) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Please check and fill out at least one item."), backgroundColor: Colors.orange));
      setState(() => _isLoading = false);
      return;
    }

    final firestore = ref.read(firestoreProvider);
    final appUser = ref.read(appUserProvider).value;
    final requisitionDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final batch = firestore.batch();
    final listDocRef = firestore.collection('dailyTodoLists').doc(requisitionDate);

    final unitsMap = await ref.read(unitsMapProvider.future);

    final itemDocs = await firestore.collection('butcher_request_items').where(FieldPath.documentId, whereIn: itemsToSubmit.map((item) => item['itemDocId'] as String).toList()).get();
    final itemNames = { for (var doc in itemDocs.docs) doc.id: (doc.data())['name'] ?? 'Unknown' };


    for (final submissionItem in itemsToSubmit) {
      final unitName = unitsMap[submissionItem['unitRef'].id] ?? '';
      final itemName = itemNames[submissionItem['itemDocId']] ?? 'Unknown Item';

      final taskRef = listDocRef.collection('stockRequisitions').doc();
      batch.set(taskRef, {
        'taskName': 'From Butcher: ${submissionItem['quantity']} $unitName of $itemName',
        'category': 'Butcher Requisition',
        'requestedBy': appUser?.fullName ?? 'Butcher',
        'createdAt': FieldValue.serverTimestamp(),
        'isCompleted': false,
        'originalRequestItemRef': firestore.collection('butcher_request_items').doc(submissionItem['itemDocId']),
        'quantity': num.tryParse(submissionItem['quantity']) ?? 0,
        'unitRef': submissionItem['unitRef'],
      });
    }

    try {
      await batch.commit();
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Requisition submitted successfully!"), backgroundColor: Colors.green));
      if (mounted) {
        navigator.pop();
      }
    } catch(e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text("Failed to submit requisition: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Requisition Form'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text("Requisition for Date"),
                subtitle: Text(DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).primaryColor)),
                onTap: () => _selectDate(context),
              ),
            ),
          ),
          _RequisitionList(formState: _formState),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitRequisition,
              icon: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send),
              label: const Text("Submit Requisition to Kitchen"),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequisitionList extends ConsumerWidget {
  final Map<String, RequisitionFormData> formState;
  const _RequisitionList({required this.formState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestableItemsAsync = ref.watch(butcherRequestableItemsProvider);

    return Expanded(
      child: requestableItemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("Error: $err\n\nThis may be due to a missing Firestore Index. Please check the debug console for a link to create it.", textAlign: TextAlign.center),
        )),
        data: (snapshot) {
          if (snapshot.isEmpty) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text("No items have been configured for the butcher by an Admin yet."),
            ));
          }

          for (final doc in snapshot) {
            if (!formState.containsKey(doc.id)) {
              formState[doc.id] = RequisitionFormData();
            }
          }

          return ListView.builder(
            itemCount: snapshot.length,
            itemBuilder: (context, index) {
              final itemDoc = snapshot[index];
              return _RequisitionItemTile(itemDoc: itemDoc, formData: formState[itemDoc.id]!);
            },
          );
        },
      ),
    );
  }
}

class _RequisitionItemTile extends StatefulWidget {
  final DocumentSnapshot itemDoc;
  final RequisitionFormData formData;
  const _RequisitionItemTile({required this.itemDoc, required this.formData});
  @override
  State<_RequisitionItemTile> createState() => _RequisitionItemTileState();
}

class _RequisitionItemTileState extends State<_RequisitionItemTile> {
  @override
  Widget build(BuildContext context) {
    final data = widget.itemDoc.data() as Map<String, dynamic>;
    final itemName = data['name'] ?? 'Unnamed';
    final List<DocumentReference> allowedUnitRefs = data['allowedUnitRefs'] != null
        ? List<DocumentReference>.from(data['allowedUnitRefs'])
        : [];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 8.0, 16.0, 8.0),
        child: Row(
          children: [
            Checkbox(
              value: widget.formData.isChecked,
              onChanged: (value) => setState(() => widget.formData.isChecked = value ?? false),
            ),
            Expanded(flex: 3, child: Text(itemName, style: const TextStyle(fontSize: 16))),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: widget.formData.quantityController,
                enabled: widget.formData.isChecked,
                decoration: const InputDecoration(labelText: 'Amount', isDense: true, border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FutureBuilder<List<Unit>>(
                  future: _fetchUnits(allowedUnitRefs),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2,)));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text("No Units");
                    }

                    final units = snapshot.data!;

                    return DropdownButtonFormField<DocumentReference>(
                      value: widget.formData.selectedUnitRef,
                      hint: const Text("Unit"),
                      items: units.map((unit) => DropdownMenuItem(
                        // --- THIS IS THE FIX ---
                          value: FirebaseFirestore.instance.collection('units').doc(unit.id),
                          child: Text(unit.name)
                      )).toList(),
                      onChanged: widget.formData.isChecked
                          ? (value) => setState(() => widget.formData.selectedUnitRef = value)
                          : null,
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    );
                  }
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Unit>> _fetchUnits(List<DocumentReference> refs) async {
    if (refs.isEmpty) return [];
    final unitFutures = refs.map((ref) => ref.get()).toList();
    final unitSnapshots = await Future.wait(unitFutures);
    return unitSnapshots.map((doc) => Unit.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }
}
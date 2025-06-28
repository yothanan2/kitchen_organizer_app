// lib/butcher_requisition_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // For more collection utilities
import 'providers.dart'; // Assuming this contains firestoreProvider and other necessary providers

// Define RequisitionFormData here, as it's specific to this screen
class RequisitionFormData {
  bool isChecked;
  final TextEditingController quantityController;
  String? selectedUnitId;
  RequisitionFormData() : isChecked = false, quantityController = TextEditingController();
}

// Riverpod provider to fetch all inventory items that are flagged as isButcherItem
final butcherRequestableItemsProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  final firestore = ref.read(firestoreProvider);
  return firestore.collection('inventoryItems').where('isButcherItem', isEqualTo: true).orderBy('itemName').snapshots();
});

// Riverpod provider to fetch all units
final unitsStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  final firestore = ref.read(firestoreProvider);
  return firestore.collection('units').snapshots();
});

// Riverpod provider to get units as a map for easy lookup
final unitsMapProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final unitsSnapshot = await ref.watch(unitsStreamProvider.future);
  return {
    for (var doc in unitsSnapshot.docs)
      doc.id: (doc.data() as Map<String, dynamic>)['name'] as String? ?? 'Unnamed Unit'
  };
});


class ButcherRequisitionScreen extends ConsumerStatefulWidget {
  const ButcherRequisitionScreen({super.key});

  @override
  ConsumerState<ButcherRequisitionScreen> createState() => _ButcherRequisitionScreenState();
}

class _ButcherRequisitionScreenState extends ConsumerState<ButcherRequisitionScreen> {
  // REVERTED: Default selected date is now tomorrow's date again.
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
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitRequisition() async {
    setState(() => _isLoading = true);
    final List<Map<String, dynamic>> itemsToSubmit = [];
    final allRequestableItemsSnapshot = await ref.read(butcherRequestableItemsProvider.future);

    _formState.forEach((docId, formData) {
      if (formData.isChecked && formData.quantityController.text.isNotEmpty && formData.selectedUnitId != null) {
        final originalItemDoc = allRequestableItemsSnapshot.docs.firstWhereOrNull((doc) => doc.id == docId);
        if (originalItemDoc != null) {
          itemsToSubmit.add({
            'itemRef': originalItemDoc.reference,
            'itemName': (originalItemDoc.data() as Map<String, dynamic>)['itemName'],
            'quantity': formData.quantityController.text,
            'unitId': formData.selectedUnitId!,
          });
        }
      }
    });


    if (itemsToSubmit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please check and fill out at least one item."), backgroundColor: Colors.orange));
      setState(() => _isLoading = false);
      return;
    }

    final firestore = ref.read(firestoreProvider);
    final appUser = ref.read(appUserProvider).value;
    final requisitionDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final batch = firestore.batch();
    final listDocRef = firestore.collection('dailyTodoLists').doc(requisitionDate);
    final unitsMap = await ref.read(unitsMapProvider.future);

    for (final submissionItem in itemsToSubmit) {
      final unitName = unitsMap[submissionItem['unitId']] ?? '';
      final taskRef = listDocRef.collection('stockRequisitions').doc();
      batch.set(taskRef, {
        'taskName': 'From Butcher: ${submissionItem['quantity']} $unitName of ${submissionItem['itemName']}',
        'category': 'Butcher Requisition',
        'requestedBy': appUser?.fullName ?? 'Butcher',
        'createdAt': FieldValue.serverTimestamp(),
        'inventoryItemRef': submissionItem['itemRef'],
        'quantity': num.tryParse(submissionItem['quantity']) ?? 0,
        'unitRef': firestore.collection('units').doc(submissionItem['unitId']),
        'isCompleted': false,
      });
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Requisition submitted successfully!"), backgroundColor: Colors.green));
        _formState.forEach((key, value) {
          value.isChecked = false;
          value.quantityController.clear();
          value.selectedUnitId = null;
        });
        setState(() {});
      }
    } catch(e) {
      print('Firestore Batch Commit Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to submit requisition: $e"), backgroundColor: Colors.red));
      }
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
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.all(8.0), child: Text("Requisition Details", style: Theme.of(context).textTheme.titleLarge)),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text("Requisition for Date"),
                      subtitle: Text(DateFormat('EEEE, MMMM d,yyyy').format(_selectedDate)),
                      onTap: () => _selectDate(context),
                    ),
                  ],
                ),
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
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
    final unitsAsync = ref.watch(unitsStreamProvider);

    return Expanded(
      child: requestableItemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("Error: $err\n\nThis may be due to a missing Firestore Index. Please check the debug console for a link to create it.", textAlign: TextAlign.center),
        )),
        data: (snapshot) {
          if (snapshot.docs.isEmpty) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text("No items have been flagged for the butcher by the Admin yet."),
            ));
          }

          for (final doc in snapshot.docs) {
            if (!formState.containsKey(doc.id)) {
              formState[doc.id] = RequisitionFormData();
            }
          }

          return ListView.builder(
            itemCount: snapshot.docs.length,
            itemBuilder: (context, index) {
              final itemDoc = snapshot.docs[index];
              final itemName = (itemDoc.data() as Map<String, dynamic>)['itemName'] ?? 'Unnamed';
              final formData = formState[itemDoc.id]!;
              return _RequisitionItemTile(itemName: itemName, formData: formData, availableUnits: unitsAsync.asData?.value.docs ?? []);
            },
          );
        },
      ),
    );
  }
}

class _RequisitionItemTile extends StatefulWidget {
  final String itemName;
  final RequisitionFormData formData;
  final List<QueryDocumentSnapshot> availableUnits;
  const _RequisitionItemTile({required this.itemName, required this.formData, required this.availableUnits});
  @override
  State<_RequisitionItemTile> createState() => _RequisitionItemTileState();
}

class _RequisitionItemTileState extends State<_RequisitionItemTile> {
  @override
  Widget build(BuildContext context) {
    final unitDropdownItems = widget.availableUnits.map((doc) => DropdownMenuItem<String>(
      value: doc.id,
      child: Text((doc.data() as Map<String, dynamic>)['name'] as String? ?? 'Unnamed Unit'),
    )).toList();
    final currentUnitId = widget.formData.selectedUnitId;
    final valueExists = unitDropdownItems.any((item) => item.value == currentUnitId);

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
            Expanded(flex: 3, child: Text(widget.itemName, style: const TextStyle(fontSize: 16))),
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
              child: DropdownButtonFormField<String>(
                value: valueExists ? currentUnitId : null,
                hint: const Text("Unit"),
                items: unitDropdownItems,
                onChanged: widget.formData.isChecked ? (value) => setState(() => widget.formData.selectedUnitId = value) : null,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

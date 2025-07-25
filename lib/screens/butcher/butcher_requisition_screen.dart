// lib/butcher_requisition_screen.dart
// FINAL: Correctly saves the unit name as a string during submission.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:kitchen_organizer_app/providers.dart';
import 'package:kitchen_organizer_app/models/models.dart';

// --- Local data models ---
class Unit {
  final String id;
  final String name;
  Unit({required this.id, required this.name});

  factory Unit.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Unit(
      id: documentId,
      name: data['name'] ?? 'Unnamed Unit',
    );
  }
}

class RequisitionFormData {
  bool isChecked;
  final TextEditingController quantityController;
  DocumentReference? selectedUnitRef;
  String? selectedUnitName; // To hold the unit name string
  RequisitionFormData()
      : isChecked = false,
        quantityController = TextEditingController();
}
// --- End of local data models ---

final butcherRequestableItemsProvider =
StreamProvider.autoDispose<List<QueryDocumentSnapshot>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('butcher_request_items')
      .orderBy('order')
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

class ButcherRequisitionScreen extends ConsumerStatefulWidget {
  final List<RequisitionItem>? reorderItems;
  const ButcherRequisitionScreen({super.key, this.reorderItems});

  @override
  ConsumerState<ButcherRequisitionScreen> createState() =>
      _ButcherRequisitionScreenState();
}

class _ButcherRequisitionScreenState
    extends ConsumerState<ButcherRequisitionScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  bool _isLoading = false;
  final Map<String, RequisitionFormData> _formState = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.reorderItems != null) {
      _initializeFormWithReorderItems();
    }
  }

  void _initializeFormWithReorderItems() {
    final allRequestableItemsAsync = ref.read(butcherRequestableItemsProvider);

    allRequestableItemsAsync.whenData((items) {
      for (final reorderItem in widget.reorderItems!) {
        final matchingItem = items.firstWhereOrNull(
          (item) => (item.data() as Map<String, dynamic>)['name'] == reorderItem.itemName,
        );

        if (matchingItem != null) {
          final docId = matchingItem.id;
          _formState[docId] = RequisitionFormData()
            ..isChecked = true
            ..quantityController.text = reorderItem.quantity.toString()
            ..selectedUnitName = reorderItem.unit;
        }
      }
      setState(() {});
    });
  }

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
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  // --- THIS IS THE UPDATED SUBMIT FUNCTION ---
  Future<void> _submitRequisition() async {
    setState(() => _isLoading = true);

    final List<Map<String, dynamic>> itemsToSubmit = [];
    final allRequestableItemsSnapshot =
    await ref.read(butcherRequestableItemsProvider.future);

    _formState.forEach((docId, formData) {
      if (formData.isChecked &&
          formData.quantityController.text.isNotEmpty &&
          formData.selectedUnitRef != null) {
        final originalItemDoc =
        allRequestableItemsSnapshot.firstWhereOrNull((doc) => doc.id == docId);
        if (originalItemDoc != null) {
          final itemData = originalItemDoc.data() as Map<String, dynamic>;
          itemsToSubmit.add({
            'itemRef': originalItemDoc.reference,
            'itemName': itemData['name'],
            'source': itemData['source'],
            'quantity': num.tryParse(formData.quantityController.text) ?? 0,
            'unitRef': formData.selectedUnitRef!,
            // --- THE FIX: Also save the unit name directly ---
            'unit': formData.selectedUnitName,
          });
        }
      }
    });

    if (itemsToSubmit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please check and fill out at least one item."),
          backgroundColor: Colors.orange));
      setState(() => _isLoading = false);
      return;
    }

    final firestore = ref.read(firestoreProvider);
    final appUser = ref.read(appUserProvider).value;

    final requisitionDoc = firestore.collection('requisitions').doc();

    try {
      await requisitionDoc.set({
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': appUser?.fullName ?? 'Butcher',
        'userId': appUser?.uid,
        'requisitionForDate': Timestamp.fromDate(_selectedDate),
        'status': 'requested',
        'items': itemsToSubmit,
        'department': 'butcher',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Requisition submitted successfully!"),
            backgroundColor: Colors.green));
        _formState.forEach((key, value) {
          value.isChecked = false;
          value.quantityController.clear();
          value.selectedUnitRef = null;
          value.selectedUnitName = null;
        });
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Failed to submit requisition: $e"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  // --- END OF UPDATED SUBMIT FUNCTION ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Daily Requisition Form'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text("Requisition for Date"),
                  subtitle: Text(DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Theme.of(context).primaryColor)),
                  onTap: () => _selectDate(context),
                ),
              ),
            ),
            _RequisitionList(formState: _formState),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitRequisition,
                icon: _isLoading
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child:
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send),
                label: const Text("Submit Requisition to Kitchen"),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
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
        error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                  "Error: $err\n\nThis may be due to a missing Firestore Index. Please check the debug console for a link to create it.",
                  textAlign: TextAlign.center),
            )),
        data: (snapshot) {
          if (snapshot.isEmpty) {
            return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                      "No items have been configured for the butcher by an Admin yet."),
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
              return _RequisitionItemTile(
                  itemDoc: itemDoc, formData: formState[itemDoc.id]!);
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
    final source = data['source'] as String?;

    final List<DocumentReference> allowedUnitRefs =
    data['allowedUnitRefs'] != null
        ? List<DocumentReference>.from(data['allowedUnitRefs'])
        : [];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 8.0, 16.0, 8.0),
        child: Wrap(
          spacing: 8.0,
          runSpacing: 12.0,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: widget.formData.isChecked,
                  onChanged: (value) =>
                      setState(() => widget.formData.isChecked = value ?? false),
                ),
                Flexible(
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: <TextSpan>[
                        TextSpan(
                            text: itemName, style: const TextStyle(fontSize: 16)),
                        if (source != null)
                          TextSpan(
                              text: ' ($source)',
                              style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    controller: widget.formData.quantityController,
                    enabled: widget.formData.isChecked,
                    decoration: const InputDecoration(
                        labelText: 'Amount',
                        isDense: true,
                        border: OutlineInputBorder()),
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
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
                        final unitDropdownItems = units.map((unit) {
                          return DropdownMenuItem<DocumentReference>(
                              value: FirebaseFirestore.instance
                                  .collection('units')
                                  .doc(unit.id),
                              child: Text(unit.name));
                        }).toList();

                        final valueExists = unitDropdownItems.any((item) => item.value?.id == widget.formData.selectedUnitRef?.id);

                        return DropdownButtonFormField<DocumentReference>(
                          value: valueExists ? widget.formData.selectedUnitRef : null,
                          hint: const Text("Unit"),
                          isExpanded: true,
                          items: unitDropdownItems,
                          onChanged: widget.formData.isChecked
                              ? (value) {
                            setState(() {
                              widget.formData.selectedUnitRef = value;
                              // --- THE FIX: Store the name when the ref changes ---
                              widget.formData.selectedUnitName = units
                                  .firstWhereOrNull((u) =>
                              u.id == value?.id)
                                  ?.name;
                            });
                          }
                              : null,
                          decoration: const InputDecoration(
                              isDense: true, border: OutlineInputBorder()),
                        );
                      }),
                ),
              ],
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
    return unitSnapshots
        .map((doc) =>
        Unit.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
}
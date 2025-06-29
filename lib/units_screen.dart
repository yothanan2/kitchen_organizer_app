// lib/units_screen.dart
// UPDATED: Implemented "Safe Delete" to prevent deleting a unit that is in use.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  final TextEditingController _unitController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showUnitDialog({DocumentSnapshot? unitDocument}) {
    String originalName = '';
    if (unitDocument != null) {
      final data = unitDocument.data() as Map<String, dynamic>?;
      originalName = data?['name'] as String? ?? '';
      _unitController.text = originalName;
    } else {
      _unitController.clear();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(unitDocument == null ? 'Add New Unit' : 'Edit Unit'),
          content: TextField(
            controller: _unitController,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Enter unit name (e.g., kg)"),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () async {
                final unitName = _unitController.text.trim();
                if (unitName.isNotEmpty) {
                  final collection = _firestore.collection('units');
                  try {
                    if (unitDocument == null) {
                      await collection.add({
                        'name': unitName,
                        'createdOn': FieldValue.serverTimestamp(),
                      });
                    } else {
                      await collection.doc(unitDocument.id).update({'name': unitName});
                    }
                    if (!mounted) return;
                    Navigator.of(dialogContext).pop();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving unit: ${e.toString()}')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    ).then((_) {
      _unitController.clear();
    });
  }

  // --- THIS IS THE MODIFIED FUNCTION ---
  Future<void> _showDeleteConfirmDialog(String docId, String unitName) async {
    // 1. Create a reference to the document we might delete.
    final unitRef = _firestore.collection('units').doc(docId);

    // 2. Check if any inventory items are using this unit.
    final linkedItemsQuery = await _firestore
        .collection('inventoryItems')
        .where('unit', isEqualTo: unitRef)
        .limit(1)
        .get();

    if (!mounted) return;

    // 3. If items are linked, show an error dialog and stop.
    if (linkedItemsQuery.docs.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Unit'),
          content: Text('The unit "$unitName" cannot be deleted because it is currently in use by one or more inventory items. Please re-assign those items to another unit first.'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return; // Stop the function here
    }

    // 4. If no items are linked, proceed with the original confirmation dialog.
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete "$unitName"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () async {
                try {
                  await unitRef.delete();
                  if (!mounted) return;
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"$unitName" deleted successfully.')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting unit: ${e.toString()}')),
                  );
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Units'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('units').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('Firestore Stream Error: ${snapshot.error}');
            return const Center(child: Text('Something went wrong. Please try again.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No units found. Tap the + button to add your first unit!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          final units = snapshot.data!.docs;

          return ListView.builder(
            itemCount: units.length,
            itemBuilder: (context, index) {
              final unitDocument = units[index];
              final data = unitDocument.data() as Map<String, dynamic>?;
              final unitName = data?['name'] as String? ?? 'Unnamed Unit';

              return ListTile(
                title: Text(unitName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Edit $unitName',
                      onPressed: () => _showUnitDialog(unitDocument: unitDocument),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete $unitName',
                      onPressed: () => _showDeleteConfirmDialog(unitDocument.id, unitName),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUnitDialog(),
        tooltip: 'Add New Unit',
        child: const Icon(Icons.add),
      ),
    );
  }
}
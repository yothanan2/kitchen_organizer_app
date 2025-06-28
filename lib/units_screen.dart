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

  // Function to show a dialog for adding or editing a unit
  void _showUnitDialog({DocumentSnapshot? unitDocument}) {
    String originalName = '';
    // If we are editing, pre-fill the text field
    if (unitDocument != null) {
      // Safely access data, providing default if not a Map or 'name' is missing
      final data = unitDocument.data() as Map<String, dynamic>?;
      originalName = data?['name'] as String? ?? '';
      _unitController.text = originalName;
    } else {
      // If adding, make sure the field is clear
      _unitController.clear();
    }

    // Ensure dialog is shown only if context is still mounted
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) { // Use a different context name for clarity
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
                Navigator.of(dialogContext).pop(); // Use dialogContext
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () async { // Make async for Firestore operations
                final unitName = _unitController.text.trim();
                if (unitName.isNotEmpty) {
                  final collection = _firestore.collection('units');
                  try {
                    if (unitDocument == null) {
                      // Add new unit
                      await collection.add({
                        'name': unitName,
                        'createdOn': FieldValue.serverTimestamp(),
                      });
                    } else {
                      // Update existing unit
                      await collection.doc(unitDocument.id).update({'name': unitName});
                    }
                    if (!mounted) return; // Check mount status AFTER async operation
                    Navigator.of(dialogContext).pop(); // Close the dialog using dialogContext
                  } catch (e) {
                    // Handle potential errors (e.g., network issues, permissions)
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving unit: ${e.toString()}')),
                    );
                    // Optionally, you might not want to pop the dialog on error
                    // or provide more specific error feedback.
                  }
                }
              },
            ),
          ],
        );
      },
    ).then((_) {
      // Clear the controller when the dialog is dismissed,
      // regardless of how it was dismissed.
      // This is good practice if the controller is reused.
      _unitController.clear();
    });
  }

  // Function to show a confirmation dialog before deleting
  Future<void> _showDeleteConfirmDialog(String docId, String unitName) async {
    // Ensure dialog is shown only if context is still mounted
    if (!mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext dialogContext) { // Use a different context name
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete "$unitName"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Use dialogContext
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () async { // Make async for Firestore operations
                try {
                  await _firestore.collection('units').doc(docId).delete();
                  if (!mounted) return; // Check mount status AFTER async operation
                  Navigator.of(dialogContext).pop(); // Close the dialog using dialogContext
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"$unitName" deleted successfully.')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting unit: ${e.toString()}')),
                  );
                  // Optionally, pop the dialog even on error, or handle differently.
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
    _unitController.dispose(); // Dispose the controller when the widget is removed
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
            // Log the error for debugging
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
              // Use a more robust way to get data and handle potential nulls or wrong types
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
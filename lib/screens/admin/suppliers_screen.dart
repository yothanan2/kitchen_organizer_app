// lib/suppliers_screen.dart
// MODIFIED: Implemented "Safe Delete" to prevent deleting a supplier that is in use.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _orderEmailController = TextEditingController();

  final CollectionReference _suppliersCollection = FirebaseFirestore.instance.collection('suppliers');

  void _showSupplierDialog({DocumentSnapshot? supplierDocument}) {
    if (supplierDocument != null) {
      final data = supplierDocument.data() as Map<String, dynamic>;
      _supplierController.text = data['name'] ?? '';
      _contactPersonController.text = data['contactPerson'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _emailController.text = data['email'] ?? '';
      _orderEmailController.text = data['orderEmail'] ?? '';
    } else {
      _supplierController.clear();
      _contactPersonController.clear();
      _phoneController.clear();
      _emailController.clear();
      _orderEmailController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(supplierDocument == null ? 'Add New Supplier' : 'Edit Supplier'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _supplierController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: "Supplier Name (Required)"),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _orderEmailController,
                  decoration: const InputDecoration(labelText: "Order Email Address (Optional)"),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                TextField(
                  controller: _contactPersonController,
                  decoration: const InputDecoration(labelText: "Contact Person (Optional)"),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: "Phone Number (Optional)"),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "General Email Address (Optional)"),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () async {
                final supplierName = _supplierController.text.trim();
                if (supplierName.isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Supplier Name is required.')),
                  );
                  return;
                }

                final Map<String, dynamic> dataToSave = {
                  'name': supplierName,
                  'contactPerson': _contactPersonController.text.trim(),
                  'phone': _phoneController.text.trim(),
                  'email': _emailController.text.trim(),
                  'orderEmail': _orderEmailController.text.trim(),
                };

                if (supplierDocument == null) {
                  await _suppliersCollection.add(dataToSave);
                } else {
                  await _suppliersCollection.doc(supplierDocument.id).update(dataToSave);
                }
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // --- MODIFIED: This function now performs a check before deleting ---
  Future<void> _showDeleteConfirmDialog(String docId, String supplierName) async {
    // 1. Check if any inventory items are linked to this supplier.
    final supplierRef = _suppliersCollection.doc(docId);
    final linkedItemsQuery = await FirebaseFirestore.instance
        .collection('inventoryItems')
        .where('supplier', isEqualTo: supplierRef)
        .limit(1)
        .get();

    if (!mounted) return;

    // 2. If items are linked, show an error and prevent deletion.
    if (linkedItemsQuery.docs.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Supplier'),
          content: Text('The supplier "$supplierName" cannot be deleted because it is currently linked to one or more inventory items. Please re-assign those items to another supplier first.'),
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

    // 3. If no items are linked, proceed with the confirmation dialog as before.
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the supplier "$supplierName"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () async {
                await _suppliersCollection.doc(docId).delete();
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _orderEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Suppliers'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _suppliersCollection.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No suppliers found. Add one!'));
          }

          final suppliers = snapshot.data!.docs;

          return ListView.builder(
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              final data = supplier.data() as Map<String, dynamic>;
              final supplierName = data['name'] ?? 'Unnamed Supplier';
              final orderEmail = data['orderEmail'] as String? ?? '';
              final contactPerson = data['contactPerson'] as String? ?? '';
              final phone = data['phone'] as String? ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(supplierName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (orderEmail.isNotEmpty)
                        Text("Order Email: $orderEmail", style: const TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                      if (contactPerson.isNotEmpty) Text(contactPerson),
                      if (phone.isNotEmpty) Text(phone),
                    ],
                  ),
                  isThreeLine: orderEmail.isNotEmpty || (contactPerson.isNotEmpty && phone.isNotEmpty),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueGrey),
                        onPressed: () => _showSupplierDialog(supplierDocument: supplier),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _showDeleteConfirmDialog(supplier.id, supplierName),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSupplierDialog(),
        tooltip: 'Add Supplier',
        child: const Icon(Icons.add),
      ),
    );
  }
}
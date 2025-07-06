// lib/confirm_order_screen.dart
// CORRECTED: Updated the import to use the central FirestoreNameWidget.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:kitchen_organizer_app/widgets/firestore_name_widget.dart'; // <-- CORRECTED IMPORT

class ConfirmOrderScreen extends StatefulWidget {
  final String supplierId;
  final List<Map<String, dynamic>> items;

  const ConfirmOrderScreen({
    super.key,
    required this.supplierId,
    required this.items,
  });

  @override
  State<ConfirmOrderScreen> createState() => _ConfirmOrderScreenState();
}

class _ConfirmOrderScreenState extends State<ConfirmOrderScreen> {
  bool _isSendingEmail = false;

  late DateTime _deliveryDate;
  final _commentsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _deliveryDate = DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _selectDeliveryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _deliveryDate) {
      setState(() {
        _deliveryDate = picked;
      });
    }
  }

  Future<void> _sendConfirmedOrder() async {
    setState(() { _isSendingEmail = true; });

    // Capture context-sensitive objects before async gaps.
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final supplierDoc = await FirebaseFirestore.instance.collection('suppliers').doc(widget.supplierId).get();
    if (!supplierDoc.exists) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Supplier not found.")));
      setState(() { _isSendingEmail = false; });
      return;
    }

    final supplierData = supplierDoc.data() as Map<String, dynamic>;
    final String? recipientEmail = supplierData['orderEmail'];

    if (recipientEmail == null || recipientEmail.isEmpty) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text("This supplier does not have an 'Order Email Address'.")));
      setState(() { _isSendingEmail = false; });
      return;
    }

    final String formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(_deliveryDate);
    final String subject = "Purchase Order - Delivery on $formattedDate";

    String body = "Hello,<br><br>Please prepare the following order for delivery on <b>$formattedDate</b>:<br><ul>";
    for (var item in widget.items) {
      final itemName = item['itemName'];
      final quantity = item['quantity'];

      String unitName = '';
      if (item['unitId'] != null) {
        final unitDoc = await FirebaseFirestore.instance.collection('units').doc(item['unitId']).get();
        if (unitDoc.exists) {
          unitName = (unitDoc.data() as Map<String, dynamic>)['name'] ?? '';
        }
      }

      body += "<li>$itemName: <b>$quantity $unitName</b></li>";
    }
    body += "</ul>";

    if (_commentsController.text.trim().isNotEmpty) {
      body += "<br><br><b>Comments:</b><br>${_commentsController.text.trim().replaceAll("\n", "<br>")}";
    }

    body += "<br><br>Thank you!";

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendOrderEmail');
      await callable.call(<String, dynamic>{
        'recipientEmail': recipientEmail,
        'subject': subject,
        'body': body,
      });

      navigator.pop(true);

    } on FirebaseFunctionsException catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text("Failed to send order email: ${e.message}"), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() { _isSendingEmail = false; });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Confirm Final Order"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("ORDER FOR:", style: TextStyle(color: Colors.grey)),
            FirestoreNameWidget(
              collection: 'suppliers',
              docId: widget.supplierId,
              defaultText: "Unassigned Supplier",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text("Required Delivery Date"),
              subtitle: Text(DateFormat('EEEE, MMMM d, yyyy').format(_deliveryDate), style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _selectDeliveryDate(context),
              ),
            ),
            const Divider(),
            const SizedBox(height: 16),
            const Text("ORDER ITEMS:", style: TextStyle(color: Colors.grey)),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final itemNameWidget = item['isCustom'] == true
                    ? Text(item['itemName'], style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic))
                    : FirestoreNameWidget(collection: 'inventoryItems', docId: item['inventoryItemId'], fieldName: 'itemName', style: const TextStyle(fontSize: 18));

                return ListTile(
                  title: itemNameWidget,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${item['quantity']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      FirestoreNameWidget(collection: 'units', docId: item['unitId'], style: const TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            TextField(
              controller: _commentsController,
              decoration: const InputDecoration(
                labelText: "Comments (Optional)",
                hintText: "Add any special instructions for the supplier...",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSendingEmail ? null : _sendConfirmedOrder,
        label: const Text("Approve & Send Email"),
        icon: _isSendingEmail
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0))
            : const Icon(Icons.send_outlined),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
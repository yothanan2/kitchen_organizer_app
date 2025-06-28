// lib/import_csv_screen.dart
// MODIFIED: Updated the save logic to store a DocumentReference for the supplier.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ImportCsvScreen extends StatefulWidget {
  const ImportCsvScreen({super.key});

  @override
  State<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

class _ImportCsvScreenState extends State<ImportCsvScreen> {
  bool _isLoading = false;

  Future<void> _pickAndProcessFile() async {
    setState(() { _isLoading = true; });

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']);
      if (result == null || result.files.single.bytes == null) {
        setState(() { _isLoading = false; });
        return;
      }

      final Uint8List fileBytes = result.files.single.bytes!;
      String csvString;
      try {
        // Handle UTF-8 with BOM
        if (fileBytes.length >= 3 && fileBytes[0] == 0xEF && fileBytes[1] == 0xBB && fileBytes[2] == 0xBF) {
          csvString = utf8.decode(fileBytes.sublist(3));
        } else {
          csvString = utf8.decode(fileBytes);
        }
      } catch (e) {
        // Fallback for different encoding
        csvString = latin1.decode(fileBytes);
      }

      // --- MODIFIED: Get the supplier's DocumentReference, not just the ID ---
      final supplierQuery = await FirebaseFirestore.instance.collection('suppliers').where('name', isEqualTo: 'AB Catering').limit(1).get();
      if (supplierQuery.docs.isEmpty) throw Exception("'AB Catering' supplier not found in the database.");
      final DocumentReference supplierRef = supplierQuery.docs.first.reference;
      // --- END MODIFICATION ---

      List<List<dynamic>> rows;
      try {
        rows = const CsvToListConverter(fieldDelimiter: ';', eol: '\r\n').convert(csvString);
        if (rows.first.length <= 1) {
          rows = const CsvToListConverter(fieldDelimiter: ',', eol: '\r\n').convert(csvString);
        }
      } catch (e) {
        rows = const CsvToListConverter(fieldDelimiter: ',', eol: '\r\n').convert(csvString);
      }

      if (rows.isEmpty) throw Exception("CSV file is empty or could not be parsed.");

      final headerRow = rows.first.map((h) => h.toString().trim().toLowerCase()).toList();
      int descriptionIndex = headerRow.indexOf('beskrivelse');
      if (descriptionIndex == -1) {
        throw Exception("Could not find a 'Beskrivelse' column. Headers found: $headerRow");
      }

      final batch = FirebaseFirestore.instance.batch();
      final collectionRef = FirebaseFirestore.instance.collection('inventoryItems');
      int itemsAdded = 0;

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length > descriptionIndex) {
          final itemName = row[descriptionIndex]?.toString().trim() ?? '';
          if (itemName.isNotEmpty) {
            final newItemRef = collectionRef.doc();

            // --- MODIFIED: Save the DocumentReference to a 'supplier' field ---
            batch.set(newItemRef, {
              'itemName': itemName,
              'supplier': supplierRef, // Correct field name and data type
              'category': null, // Set to null to be consistent
              'quantityOnHand': 0,
              'minStockLevel': 0,
              'unit': null, // Set to null to be consistent
              'location': null, // Set to null to be consistent
              'lastUpdated': FieldValue.serverTimestamp(),
            });
            // --- END MODIFICATION ---
            itemsAdded++;
          }
        }
      }

      await batch.commit();

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$itemsAdded items imported successfully!"), backgroundColor: Colors.green));
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Import from CSV")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const CircularProgressIndicator()
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_upload_outlined, size: 80, color: Colors.grey),
              const SizedBox(height: 20),
              const Text(
                "Import new inventory items from a supplier's CSV file. This action will add new items and is currently configured for 'AB Catering'.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _pickAndProcessFile,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                child: const Text("Select CSV File to Import"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
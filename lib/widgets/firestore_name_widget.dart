// lib/widgets/firestore_name_widget.dart
// A single, reusable widget to get a name from any document in Firestore.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreNameWidget extends StatelessWidget {
  final String collection;
  final dynamic docId; // Can be a String or a DocumentReference
  final String fieldName;
  final TextStyle? style;
  final String defaultText;

  const FirestoreNameWidget({
    super.key,
    required this.collection,
    this.docId,
    this.fieldName = 'name',
    this.style,
    this.defaultText = 'N/A',
  });

  @override
  Widget build(BuildContext context) {
    String? finalDocId;

    if (docId is DocumentReference) {
      finalDocId = docId.id;
    } else if (docId is String) {
      finalDocId = docId;
    }

    if (finalDocId == null || finalDocId.isEmpty) {
      return Text(defaultText, style: style ?? const TextStyle(fontStyle: FontStyle.italic));
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection(collection).doc(finalDocId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text("...", style: style);
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Text("Unknown", style: style);
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        return Text(data[fieldName] ?? 'N/A', style: style);
      },
    );
  }
}
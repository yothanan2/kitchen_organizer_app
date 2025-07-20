import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:kitchen_organizer_app/firebase_options.dart';

// This script clears the error log for the current day in Firestore.
// To run this script, use the following command from your project root:
// dart run scripts/clear_error_log.dart

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final errorLogRef = firestore.collection('dailyCompletedTasks').doc(today).collection('errorLog');

  try {
    final snapshot = await errorLogRef.get();
    if (snapshot.docs.isEmpty) {
      print('No errors found for today. The log is already clear.');
      return;
    }

    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    print('Successfully cleared ${snapshot.docs.length} error(s) from the log for today.');
  } catch (e) {
    print('An error occurred: $e');
  }
}

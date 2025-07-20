import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kitchen_organizer_app/models/models.dart';

class MiseEnPlaceController {
  final FirebaseFirestore _firestore;

  MiseEnPlaceController(this._firestore);

  Future<String?> toggleTaskCompletion(PrepTask task, bool isCompleted, String? userId, String? userName) async {
    if (userId == null) {
      return 'User not logged in.';
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dailyTaskRef = _firestore.collection('dailyCompletedTasks').doc(today).collection('tasks').doc(task.id);

    try {
      if (isCompleted) {
        await dailyTaskRef.set({
          'isCompleted': true,
          'taskName': task.taskName, // Store task name for easier debugging
          'completedAt': FieldValue.serverTimestamp(),
          'completedBy': userName ?? 'Unknown User',
        }, SetOptions(merge: true));
      } else {
        // If un-checking, remove the document
        await dailyTaskRef.delete();
      }
      return null;
    } catch (e) {
      return 'Failed to update task: $e';
    }
  }
}

final miseEnPlaceControllerProvider = Provider<MiseEnPlaceController>((ref) {
  return MiseEnPlaceController(FirebaseFirestore.instance);
});

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NextDayTaskController {
  final FirebaseFirestore _firestore;

  NextDayTaskController(this._firestore);

  String get _tomorrowDateString {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateFormat('yyyy-MM-dd').format(tomorrow);
  }

  Future<void> toggleNextDayTask(String taskId, bool isSet, Map<String, dynamic> taskData) async {
    final docRef = _firestore
        .collection('nextDayTasks')
        .doc(_tomorrowDateString)
        .collection('tasks')
        .doc(taskId);

    if (isSet) {
      // Set the task for tomorrow, copying the original task data
      await docRef.set({
        ...taskData,
        'isCompleted': false, // Ensure it's not completed for tomorrow
        'completedQuantity': 0,
        'flaggedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Remove the task from tomorrow's list
      await docRef.delete();
    }
  }
}

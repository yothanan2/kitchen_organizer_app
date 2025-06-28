import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StaffTodoViewScreen extends StatefulWidget {
  const StaffTodoViewScreen({super.key});

  @override
  State<StaffTodoViewScreen> createState() => _StaffTodoViewScreenState();
}

class _StaffTodoViewScreenState extends State<StaffTodoViewScreen> {
  // We will use a map of controllers to manage the quantity for each dish
  final Map<String, TextEditingController> _quantityControllers = {};
  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // This is the new function to generate tomorrow's list based on production numbers
  Future<void> _generateListForTomorrow() async {
    setState(() { _isLoading = true; });

    // Get tomorrow's date formatted as a string
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final dateString = DateFormat('yyyy-MM-dd').format(tomorrow);

    final batch = FirebaseFirestore.instance.batch();
    final dailyListRef = FirebaseFirestore.instance.collection('dailyTodoLists').doc(dateString);

    // This map will hold all the tasks to be added
    final Map<String, Map<String, dynamic>> tasksToAdd = {};

    // Loop through all the dishes where a quantity was entered
    for (var dishId in _quantityControllers.keys) {
      final controller = _quantityControllers[dishId]!;
      final int quantity = int.tryParse(controller.text) ?? 0;

      if (quantity > 0) {
        // Fetch the prep tasks for this dish
        final dishDoc = await FirebaseFirestore.instance.collection('dishes').doc(dishId).get();
        final prepTasksSnapshot = await dishDoc.reference.collection('prepTasks').get();
        final dishName = (dishDoc.data() as Map<String, dynamic>)['dishName'] ?? 'Unknown Dish';

        // Add each prep task to our map
        for (var taskDoc in prepTasksSnapshot.docs) {
          tasksToAdd[taskDoc.id] = {
            'taskName': taskDoc['taskName'],
            'dishName': dishName,
            'forQuantity': quantity,
            'isCompleted': false,
          };
        }
      }
    }

    if (tasksToAdd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a quantity for at least one dish.')),
      );
      setState(() { _isLoading = false; });
      return;
    }

    // Set some basic info for the daily list itself
    batch.set(dailyListRef, {
      'date': dateString,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Add each unique task to the 'tasks' sub-collection
    for (var taskData in tasksToAdd.values) {
      final taskRef = dailyListRef.collection('tasks').doc(); // New empty document
      batch.set(taskRef, taskData);
    }

    // Commit all the changes to Firestore at once
    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mise en Place for $dateString has been generated!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to generate list: $e")));
    } finally {
      if(mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Plan Tomorrow's Production"),
        actions: [
          _isLoading
              ? const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)))
              : IconButton(
            icon: const Icon(Icons.save),
            onPressed: _generateListForTomorrow,
            tooltip: 'Generate List for Tomorrow',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('dishes').orderBy('dishName').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No dishes have been created by an Admin yet.'));
          }

          final dishes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: dishes.length,
            itemBuilder: (context, index) {
              final dishDoc = dishes[index];
              final dishId = dishDoc.id;
              final dishName = (dishDoc.data() as Map<String, dynamic>)['dishName'] ?? 'Unnamed Dish';

              // Create a controller for this dish if it doesn't exist
              if (!_quantityControllers.containsKey(dishId)) {
                _quantityControllers[dishId] = TextEditingController();
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(dishName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _quantityControllers[dishId],
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: "Qty",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
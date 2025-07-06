// lib/floor_checklist_screen.dart
// This is the STAFF screen for the daily checklist.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchen_organizer_app/providers.dart';

class FloorChecklistScreen extends ConsumerWidget {
  const FloorChecklistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(floorChecklistItemsProvider);
    final checklistAsync = ref.watch(dailyFloorChecklistProvider);
    final controller = ref.read(floorChecklistControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Floor Closing Checklist"),
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text("No checklist items have been configured by an Admin."));
          }

          final checklistData = checklistAsync.value?.data() as Map<String, dynamic>? ?? {};

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final itemDoc = items[index];
              final itemName = itemDoc['name'] as String;

              final bool isChecked = checklistData[itemName] ?? false;

              return CheckboxListTile(
                title: Text(itemName, style: const TextStyle(fontSize: 18)),
                value: isChecked,
                onChanged: (bool? value) {
                  controller.toggleItem(itemName, value ?? false);
                },
              );
            },
          );
        },
      ),
    );
  }
}
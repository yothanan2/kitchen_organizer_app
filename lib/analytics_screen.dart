// lib/analytics_screen.dart
// UPDATED: Added a TabBar to show multiple reports, including the new Task Completion report.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'providers.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 30));
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // We now have two reports
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analytics & Reports'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.fastfood_outlined), text: 'Ingredient Usage'),
              Tab(icon: Icon(Icons.emoji_events_outlined), text: 'Task Champions'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text('Start: ${DateFormat.yMd().format(_startDate)}'),
                      onPressed: () => _selectDate(context, true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text('End: ${DateFormat.yMd().format(_endDate)}'),
                      onPressed: () => _selectDate(context, false),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: TabBarView(
                children: [
                  // View for the first tab
                  _MostUsedIngredientsView(
                    dateRange: DateTimeRange(start: _startDate, end: _endDate),
                  ),
                  // View for the second tab
                  _TaskCompletionView(
                    dateRange: DateTimeRange(start: _startDate, end: _endDate),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A dedicated widget for the "Most Used Ingredients" report
class _MostUsedIngredientsView extends ConsumerWidget {
  final DateTimeRange dateRange;
  const _MostUsedIngredientsView({required this.dateRange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredientsAsync = ref.watch(mostUsedIngredientsProvider(dateRange));
    return ingredientsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (ingredients) {
        if (ingredients.isEmpty) {
          return const Center(
            child: Text(
              'No ingredient usage found for the selected date range.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.builder(
          itemCount: ingredients.length,
          itemBuilder: (context, index) {
            final ingredient = ingredients[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text('${index + 1}'),
              ),
              title: Text(ingredient.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text(
                '${ingredient.totalQuantity.toStringAsFixed(2)} ${ingredient.unit}',
                style: const TextStyle(fontSize: 16),
              ),
            );
          },
        );
      },
    );
  }
}

// A dedicated widget for the new "Task Completion" report
class _TaskCompletionView extends ConsumerWidget {
  final DateTimeRange dateRange;
  const _TaskCompletionView({required this.dateRange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final championsAsync = ref.watch(taskCompletionProvider(dateRange));
    return championsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (champions) {
        if (champions.isEmpty) {
          return const Center(
            child: Text(
              'No completed tasks found for the selected date range.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.builder(
          itemCount: champions.length,
          itemBuilder: (context, index) {
            final champion = champions[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: index == 0 ? Colors.amber.shade700 : null,
                child: Text('${index + 1}'),
              ),
              title: Text(champion.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text(
                '${champion.taskCount} tasks completed',
                style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
              ),
            );
          },
        );
      },
    );
  }
}
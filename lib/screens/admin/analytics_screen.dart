// lib/analytics_screen.dart
// UPDATED: Replaced ListView reports with interactive BarCharts using fl_chart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // <-- NEW IMPORT
import 'package:kitchen_organizer_app/providers.dart';

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
      length: 2,
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
                  _MostUsedIngredientsView(
                    dateRange: DateTimeRange(start: _startDate, end: _endDate),
                  ),
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
          return const Center(child: Text('No ingredient usage found for this date range.'));
        }

        final topIngredients = ingredients.take(10).toList();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: topIngredients.first.totalQuantity.toDouble() * 1.2, // Add 20% padding to the top
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.blueGrey,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final ingredient = topIngredients[groupIndex];
                    return BarTooltipItem(
                      '${ingredient.name}\n',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      children: <TextSpan>[
                        TextSpan(
                          text: '${ingredient.totalQuantity.toStringAsFixed(1)} ${ingredient.unit}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      if (value.toInt() >= topIngredients.length) return const SizedBox.shrink();
                      final ingredient = topIngredients[value.toInt()];
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 4.0,
                        child: Text(
                          ingredient.name.split(' ').first, // Show first word of name
                          style: const TextStyle(fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barGroups: topIngredients.asMap().entries.map((entry) {
                final index = entry.key;
                final ingredient = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                        toY: ingredient.totalQuantity.toDouble(),
                        color: Colors.deepPurple.shade300,
                        width: 16,
                        borderRadius: BorderRadius.circular(4)
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
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
          return const Center(child: Text('No completed tasks found for this date range.'));
        }

        final topChampions = champions.take(10).toList();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: topChampions.first.taskCount.toDouble() * 1.2,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.blueGrey,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final champion = topChampions[groupIndex];
                    return BarTooltipItem(
                      '${champion.name}\n',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      children: <TextSpan>[
                        TextSpan(
                          text: '${champion.taskCount} tasks',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      if (value.toInt() >= topChampions.length) return const SizedBox.shrink();
                      final champion = topChampions[value.toInt()];
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 4.0,
                        child: Text(champion.name, style: const TextStyle(fontSize: 10)),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barGroups: topChampions.asMap().entries.map((entry) {
                final index = entry.key;
                final champion = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                        toY: champion.taskCount.toDouble(),
                        color: Colors.teal.shade300,
                        width: 16,
                        borderRadius: BorderRadius.circular(4)
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
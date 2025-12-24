import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../models/group.dart';
import '../../models/expense.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';

/// Analytics screen with spending charts and category breakdown.
class AnalyticsScreen extends ConsumerStatefulWidget {
  final Group group;

  const AnalyticsScreen({super.key, required this.group});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _selectedMonthOffset = 0; // 0 = current month, -1 = last month, etc.

  @override
  Widget build(BuildContext context) {
    final expensesState = ref.watch(expensesStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: expensesState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Monthly Spend Chart
                  _buildMonthlySpendSection(expensesState.expenses, isDark),
                  const SizedBox(height: 24),

                  // Category Breakdown
                  _buildCategoryBreakdown(expensesState.expenses, isDark),
                  const SizedBox(height: 24),

                  // Top Spenders
                  _buildTopSpenders(expensesState.expenses, isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthlySpendSection(List<Expense> expenses, bool isDark) {
    final monthlyData = _getMonthlySpendData(expenses);
    final currentMonth = DateTime.now().subtract(Duration(days: 30 * _selectedMonthOffset));
    final monthName = DateFormat('MMMM yyyy').format(currentMonth);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Monthly Spending',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _selectedMonthOffset--;
                        });
                      },
                      iconSize: 20,
                    ),
                    Text(
                      monthName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _selectedMonthOffset >= 0
                          ? null
                          : () {
                              setState(() {
                                _selectedMonthOffset++;
                              });
                            },
                      iconSize: 20,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: monthlyData.isEmpty
                  ? Center(
                      child: Text(
                        'No expenses this month',
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _getMaxY(monthlyData),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '₹${rod.toY.toStringAsFixed(0)}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= monthlyData.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    monthlyData[index]['label'] as String,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.lightTextSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '₹${value.toInt()}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.lightTextSecondary,
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: _getMaxY(monthlyData) / 4,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.1),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: monthlyData.asMap().entries.map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: (entry.value['amount'] as double),
                                color: AppTheme.primaryColor,
                                width: 16,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown(List<Expense> expenses, bool isDark) {
    final categoryData = _getCategoryData(expenses);
    final total = categoryData.fold<double>(0, (sum, item) => sum + (item['amount'] as double));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'By Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (categoryData.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No expenses yet',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  // Pie Chart
                  Expanded(
                    child: SizedBox(
                      height: 150,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                          sections: categoryData.asMap().entries.map((entry) {
                            final color = _getCategoryColor(entry.key, categoryData.length);
                            final percentage = (entry.value['amount'] as double) / total * 100;
                            return PieChartSectionData(
                              color: color,
                              value: entry.value['amount'] as double,
                              title: percentage > 10 ? '${percentage.toStringAsFixed(0)}%' : '',
                              radius: 40,
                              titleStyle: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  // Legend
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: categoryData.asMap().entries.map((entry) {
                        final color = _getCategoryColor(entry.key, categoryData.length);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.value['name'] as String,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '₹${(entry.value['amount'] as double).toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSpenders(List<Expense> expenses, bool isDark) {
    final spenderData = _getTopSpendersData(expenses);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Spenders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (spenderData.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No expenses yet',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                ),
              )
            else
              ...spenderData.take(5).map((data) {
                final maxAmount = spenderData.first['amount'] as double;
                final percentage = (data['amount'] as double) / maxAmount;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            data['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '₹${(data['amount'] as double).toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getMonthlySpendData(List<Expense> expenses) {
    final now = DateTime.now();
    final targetMonth = DateTime(now.year, now.month + _selectedMonthOffset, 1);
    final daysInMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;

    // Group expenses by week
    final weeklyTotals = <int, double>{};
    for (var week = 1; week <= 5; week++) {
      weeklyTotals[week] = 0;
    }

    for (final expense in expenses) {
      if (expense.expenseDate.year == targetMonth.year &&
          expense.expenseDate.month == targetMonth.month) {
        final week = ((expense.expenseDate.day - 1) ~/ 7) + 1;
        final weekKey = week > 4 ? 4 : week;
        weeklyTotals[weekKey] = (weeklyTotals[weekKey] ?? 0) + expense.amount;
      }
    }

    return weeklyTotals.entries
        .where((e) => e.key <= 4)
        .map((e) => {
              'label': 'Week ${e.key}',
              'amount': e.value,
            })
        .toList();
  }

  double _getMaxY(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 100;
    final maxAmount = data.fold<double>(0, (max, item) {
      final amount = item['amount'] as double;
      return amount > max ? amount : max;
    });
    return maxAmount == 0 ? 100 : maxAmount * 1.2;
  }

  List<Map<String, dynamic>> _getCategoryData(List<Expense> expenses) {
    final categoryTotals = <String, double>{};

    for (final expense in expenses) {
      final category = expense.category?.name ?? 'Other';
      categoryTotals[category] = (categoryTotals[category] ?? 0) + expense.amount;
    }

    final result = categoryTotals.entries
        .map((e) => {'name': e.key, 'amount': e.value})
        .toList();
    result.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
    return result;
  }

  List<Map<String, dynamic>> _getTopSpendersData(List<Expense> expenses) {
    final spenderTotals = <String, double>{};

    for (final expense in expenses) {
      final paidBy = expense.paidById;
      spenderTotals[paidBy] = (spenderTotals[paidBy] ?? 0) + expense.amount;
    }

    final result = spenderTotals.entries
        .map((e) => {'name': e.key.length > 8 ? '${e.key.substring(0, 8)}...' : e.key, 'amount': e.value})
        .toList();
    result.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
    return result;
  }

  Color _getCategoryColor(int index, int total) {
    final colors = [
      AppTheme.primaryColor,
      AppTheme.secondaryColor,
      AppTheme.accentColor,
      const Color(0xFF10B981), // green
      const Color(0xFFF59E0B), // amber
      const Color(0xFFEF4444), // red
      const Color(0xFF8B5CF6), // violet
      const Color(0xFFEC4899), // pink
    ];
    return colors[index % colors.length];
  }
}

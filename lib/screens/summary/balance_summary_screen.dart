import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/group.dart';
import '../../models/balance.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';

/// Full balance summary screen with charts.
class BalanceSummaryScreen extends ConsumerWidget {
  final Group group;

  const BalanceSummaryScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesState = ref.watch(expensesStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final balances = expensesState.balanceList;
    final debts = expensesState.debtList;
    final totalExpenses = expensesState.expenses.fold(0.0, (sum, e) => sum + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Balance Summary'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Total card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF312E81), const Color(0xFF4338CA)]
                    : [AppTheme.primaryColor, AppTheme.primaryColor.withBlue(255)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  'Total Group Expenses',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${totalExpenses.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${expensesState.expenses.length} expenses',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Pie chart
          if (balances.isNotEmpty) ...[
            const Text(
              'Contribution Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: _buildPieSections(balances, totalExpenses),
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend(balances),
          ],

          const SizedBox(height: 24),

          // Settlement plan
          const Text(
            'Settlement Plan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (debts.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'All Settled Up! 🎉',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No pending settlements',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...debts.asMap().entries.map((entry) {
              final index = entry.key;
              final debt = entry.value;
              return _buildSettlementCard(debt, index + 1, isDark);
            }),

          const SizedBox(height: 24),

          // Individual balances
          const Text(
            'Individual Balances',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          ...balances.map((balance) => _buildBalanceRow(balance, isDark)),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(List<Balance> balances, double total) {
    final colors = [
      AppTheme.primaryColor,
      AppTheme.secondaryColor,
      AppTheme.accentColor,
      Colors.orange,
      Colors.teal,
      Colors.pink,
    ];

    return balances.asMap().entries.map((entry) {
      final index = entry.key;
      final balance = entry.value;
      final percentage = total > 0 ? (balance.paid / total * 100) : 0.0;

      return PieChartSectionData(
        value: balance.paid,
        title: '${percentage.toStringAsFixed(0)}%',
        color: colors[index % colors.length],
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(List<Balance> balances) {
    final colors = [
      AppTheme.primaryColor,
      AppTheme.secondaryColor,
      AppTheme.accentColor,
      Colors.orange,
      Colors.teal,
      Colors.pink,
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: balances.asMap().entries.map((entry) {
        final index = entry.key;
        final balance = entry.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              balance.displayName,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSettlementCard(SimplifiedDebt debt, int index, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.negativeBalance.withOpacity(0.1),
                      child: Text(
                        debt.fromUserName.isNotEmpty ? debt.fromUserName[0] : '?',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.negativeBalance,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 16),
                    ),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.positiveBalance.withOpacity(0.1),
                      child: Text(
                        debt.toUserName.isNotEmpty ? debt.toUserName[0] : '?',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.positiveBalance,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${debt.fromUserName} → ${debt.toUserName}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${debt.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(Balance balance, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: balance.isOwed
                ? AppTheme.positiveBalance.withOpacity(0.1)
                : balance.owesOthers
                    ? AppTheme.negativeBalance.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
            child: Text(
              balance.displayName.isNotEmpty ? balance.displayName[0] : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: balance.isOwed
                    ? AppTheme.positiveBalance
                    : balance.owesOthers
                        ? AppTheme.negativeBalance
                        : Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balance.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Paid: ₹${balance.paid.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                balance.formattedBalance,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: balance.isOwed
                      ? AppTheme.positiveBalance
                      : balance.owesOthers
                          ? AppTheme.negativeBalance
                          : Colors.grey,
                ),
              ),
              Text(
                balance.isOwed
                    ? 'gets back'
                    : balance.owesOthers
                        ? 'owes'
                        : 'settled',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

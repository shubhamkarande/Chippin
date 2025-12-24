import 'package:flutter/material.dart';

import '../models/balance.dart';
import '../theme/app_theme.dart';

/// Card widget for displaying a member's balance.
class BalanceCard extends StatelessWidget {
  final Balance balance;
  final VoidCallback? onTap;

  const BalanceCard({
    super.key,
    required this.balance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar with balance indicator
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getBalanceColor().withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _getBalanceColor().withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    balance.displayName.isNotEmpty
                        ? balance.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getBalanceColor(),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Name and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      balance.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Paid: ₹${balance.paid.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.positiveBalance,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Owes: ₹${balance.owes.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.negativeBalance,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Balance amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    balance.formattedBalance,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getBalanceColor(),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getBalanceLabel(),
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
        ),
      ),
    );
  }

  Color _getBalanceColor() {
    if (balance.isOwed) {
      return AppTheme.positiveBalance;
    } else if (balance.owesOthers) {
      return AppTheme.negativeBalance;
    } else {
      return Colors.grey;
    }
  }

  String _getBalanceLabel() {
    if (balance.isOwed) {
      return 'gets back';
    } else if (balance.owesOthers) {
      return 'owes';
    } else {
      return 'settled';
    }
  }
}

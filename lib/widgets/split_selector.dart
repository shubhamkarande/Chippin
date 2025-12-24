import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../theme/app_theme.dart';

/// Bottom sheet widget for selecting split type.
class SplitSelector extends StatelessWidget {
  final SplitType currentType;
  final Function(SplitType) onSelect;

  const SplitSelector({
    super.key,
    required this.currentType,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'How to split?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ...SplitType.values.map((type) => _buildOption(context, type)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, SplitType type) {
    final isSelected = type == currentType;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => onSelect(type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  _getIcon(type),
                  color: isSelected ? AppTheme.primaryColor : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppTheme.primaryColor : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getDescription(type),
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
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(SplitType type) {
    switch (type) {
      case SplitType.equal:
        return Icons.drag_handle;
      case SplitType.exact:
        return Icons.attach_money;
      case SplitType.percentage:
        return Icons.percent;
      case SplitType.shares:
        return Icons.pie_chart;
    }
  }

  String _getDescription(SplitType type) {
    switch (type) {
      case SplitType.equal:
        return 'Split equally among all members';
      case SplitType.exact:
        return 'Enter exact amount for each person';
      case SplitType.percentage:
        return 'Split by percentage';
      case SplitType.shares:
        return 'Split by number of shares';
    }
  }
}

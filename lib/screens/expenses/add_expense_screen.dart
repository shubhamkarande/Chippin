import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/group.dart';
import '../../models/expense.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/split_selector.dart';
import '../../widgets/category_chip.dart';

/// Screen to add a new expense manually.
class AddExpenseScreen extends ConsumerStatefulWidget {
  final Group group;
  final double? initialAmount;
  final String? initialDescription;
  final DateTime? initialDate;

  const AddExpenseScreen({
    super.key,
    required this.group,
    this.initialAmount,
    this.initialDescription,
    this.initialDate,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  late DateTime _selectedDate;
  String? _selectedCategory;
  SplitType _splitType = SplitType.equal;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(2);
    }
    if (widget.initialDescription != null) {
      _descriptionController.text = widget.initialDescription!;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _saveExpense,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Amount input (big and prominent)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    widget.group.currency,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppTheme.darkTextSecondary.withOpacity(0.3)
                            : AppTheme.lightTextSecondary.withOpacity(0.3),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter amount';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Enter valid amount';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick presets
            const Text(
              'Quick Add',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickPresetButton(
                  emoji: '🚗',
                  label: 'Uber',
                  onTap: () {
                    _descriptionController.text = 'Uber ride';
                    _selectedCategory = 'transport';
                    setState(() {});
                  },
                ),
                _QuickPresetButton(
                  emoji: '🍕',
                  label: 'Zomato',
                  onTap: () {
                    _descriptionController.text = 'Zomato order';
                    _selectedCategory = 'food';
                    setState(() {});
                  },
                ),
                _QuickPresetButton(
                  emoji: '🏠',
                  label: 'Rent',
                  onTap: () {
                    _descriptionController.text = 'Monthly rent';
                    _selectedCategory = 'rent';
                    setState(() {});
                  },
                ),
                _QuickPresetButton(
                  emoji: '💡',
                  label: 'Bills',
                  onTap: () {
                    _descriptionController.text = 'Utility bills';
                    _selectedCategory = 'utilities';
                    setState(() {});
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Description
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What was this expense for?',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Category selector
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExpenseCategory.presets.map((category) {
                final isSelected = _selectedCategory == category.id;
                return CategoryChip(
                  category: category,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedCategory = isSelected ? null : category.id;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Date picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: AppTheme.primaryColor,
                ),
              ),
              title: const Text('Date'),
              subtitle: Text(
                DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),

            const Divider(),

            // Paid by
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person,
                  color: AppTheme.secondaryColor,
                ),
              ),
              title: const Text('Paid by'),
              subtitle: Text(user?.displayName ?? 'You'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Member selector
              },
            ),

            const Divider(),

            // Split type
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pie_chart,
                  color: AppTheme.accentColor,
                ),
              ),
              title: const Text('Split'),
              subtitle: Text(_splitType.displayName),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showSplitOptions,
            ),

            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Add any additional details',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _saveExpense,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Add Expense',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showSplitOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SplitSelector(
        currentType: _splitType,
        onSelect: (type) {
          setState(() {
            _splitType = type;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _saveExpense() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
    });

    final user = ref.read(authStateProvider).user;
    if (user == null) {
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    try {
      await ref.read(expensesStateProvider.notifier).createExpense(
            groupId: widget.group.id,
            description: _descriptionController.text.trim(),
            amount: double.parse(_amountController.text),
            paidById: user.id,
            createdById: user.id,
            categoryId: _selectedCategory,
            splitType: _splitType,
            expenseDate: _selectedDate,
            notes: _notesController.text.trim(),
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense added!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

class _QuickPresetButton extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _QuickPresetButton({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

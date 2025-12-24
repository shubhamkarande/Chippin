import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/group.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';

/// Screen for exporting group data to PDF/CSV.
class ExportScreen extends ConsumerStatefulWidget {
  final Group group;

  const ExportScreen({super.key, required this.group});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _isExporting = false;
  File? _generatedFile;
  String? _error;
  String _selectedFormat = 'pdf';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expensesState = ref.watch(expensesStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Data'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Format selector
          const Text(
            'Select Format',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _FormatOption(
                  icon: Icons.picture_as_pdf,
                  title: 'PDF',
                  subtitle: 'Full report with charts',
                  isSelected: _selectedFormat == 'pdf',
                  onTap: () {
                    setState(() {
                      _selectedFormat = 'pdf';
                      _generatedFile = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FormatOption(
                  icon: Icons.table_chart,
                  title: 'CSV',
                  subtitle: 'Spreadsheet data',
                  isSelected: _selectedFormat == 'csv',
                  onTap: () {
                    setState(() {
                      _selectedFormat = 'csv';
                      _generatedFile = null;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Preview info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Export Preview',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoItem('Group', widget.group.name),
                _buildInfoItem('Expenses', '${expensesState.expenses.length} items'),
                _buildInfoItem('Members', '${widget.group.memberCount} members'),
                _buildInfoItem(
                  'Total',
                  '₹${expensesState.expenses.fold(0.0, (sum, e) => sum + e.amount).toStringAsFixed(2)}',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // What's included
          const Text(
            'What\'s Included',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (_selectedFormat == 'pdf') ...[
            _buildFeatureItem('Summary with total expenses', true),
            _buildFeatureItem('Individual member balances', true),
            _buildFeatureItem('Settlement plan', true),
            _buildFeatureItem('Detailed expense list', true),
            _buildFeatureItem('Professional formatting', true),
          ] else ...[
            _buildFeatureItem('All expense details', true),
            _buildFeatureItem('Dates and amounts', true),
            _buildFeatureItem('Categories and notes', true),
            _buildFeatureItem('Easy to import to Excel', true),
            _buildFeatureItem('Charts and formatting', false),
          ],

          const SizedBox(height: 32),

          // Error message
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: AppTheme.errorColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppTheme.errorColor),
                    ),
                  ),
                ],
              ),
            ),

          // Generated file info
          if (_generatedFile != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
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
                    'Export Ready!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _previewFile,
                          icon: const Icon(Icons.visibility),
                          label: const Text('Preview'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _shareFile,
                          icon: const Icon(Icons.share),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Export button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isExporting ? null : _export,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isExporting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Generating...'),
                      ],
                    )
                  : Text(
                      'Generate ${_selectedFormat.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text, bool included) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            included ? Icons.check_circle : Icons.cancel,
            size: 20,
            color: included ? AppTheme.successColor : Colors.grey,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: included ? null : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    setState(() {
      _isExporting = true;
      _error = null;
      _generatedFile = null;
    });

    try {
      final exportService = ref.read(exportServiceProvider);
      final expensesState = ref.read(expensesStateProvider);

      File file;
      if (_selectedFormat == 'pdf') {
        file = await exportService.exportToPdf(
          group: widget.group,
          expenses: expensesState.expenses,
          balances: expensesState.balanceList,
          debts: expensesState.debtList,
        );
      } else {
        file = await exportService.exportToCsv(
          group: widget.group,
          expenses: expensesState.expenses,
        );
      }

      setState(() {
        _generatedFile = file;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to generate export: $e';
      });
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  void _previewFile() {
    if (_generatedFile == null) return;

    if (_selectedFormat == 'pdf') {
      ref.read(exportServiceProvider).previewPdf(context, _generatedFile!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV preview not available. Use Share instead.')),
      );
    }
  }

  void _shareFile() {
    if (_generatedFile == null) return;
    ref.read(exportServiceProvider).shareFile(_generatedFile!);
  }
}

class _FormatOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? AppTheme.primaryColor : Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.primaryColor : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
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
    );
  }
}

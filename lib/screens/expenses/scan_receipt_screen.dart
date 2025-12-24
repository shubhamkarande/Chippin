import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/group.dart';
import '../../services/ocr_service.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import 'add_expense_screen.dart';

/// Screen to scan and process receipts.
class ScanReceiptScreen extends ConsumerStatefulWidget {
  final Group group;

  const ScanReceiptScreen({super.key, required this.group});

  @override
  ConsumerState<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends ConsumerState<ScanReceiptScreen> {
  OcrResult? _result;
  bool _isProcessing = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final ocrService = ref.watch(ocrServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
      ),
      body: _result != null
          ? _buildResultView()
          : _buildScanOptions(ocrService, isDark),
    );
  }

  Widget _buildScanOptions(OcrService ocrService, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessing) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text('Processing receipt...'),
            ] else if (_error != null) ...[
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.errorColor),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                  });
                },
                child: const Text('Try Again'),
              ),
            ] else ...[
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long,
                  size: 60,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Scan a Receipt',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Take a photo or select from gallery\nto automatically extract expense details',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _scanFromGallery(ocrService),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _scanFromCamera(ocrService),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultView() {
    final result = _result!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Success indicator
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: AppTheme.successColor,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receipt Scanned!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Review the extracted details below',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Extracted total
        if (result.total != null) ...[
          const Text(
            'Total Amount',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '₹${result.total!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Merchant name
        if (result.merchantName != null) ...[
          _buildInfoRow(
            'Merchant',
            result.merchantName!,
            Icons.store,
          ),
          const SizedBox(height: 16),
        ],

        // Date
        if (result.date != null) ...[
          _buildInfoRow(
            'Date',
            '${result.date!.day}/${result.date!.month}/${result.date!.year}',
            Icons.calendar_today,
          ),
          const SizedBox(height: 16),
        ],

        // Line items
        if (result.items.isNotEmpty) ...[
          const Text(
            'Items Found',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: result.items.map((item) {
                return ListTile(
                  title: Text(item.description),
                  trailing: item.price != null
                      ? Text(
                          '₹${item.price!.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                      : null,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Raw text (collapsible)
        ExpansionTile(
          title: const Text('Raw Text'),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black12 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result.rawText,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _result = null;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Scan Again'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _useResult,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Use This'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _scanFromCamera(OcrService service) async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final result = await service.scanFromCamera();
      if (result.success) {
        setState(() {
          _result = result;
        });
      } else {
        setState(() {
          _error = result.error ?? 'Failed to process receipt';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _scanFromGallery(OcrService service) async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final result = await service.scanFromGallery();
      if (result.success) {
        setState(() {
          _result = result;
        });
      } else {
        setState(() {
          _error = result.error ?? 'Failed to process receipt';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _useResult() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(
          group: widget.group,
          initialAmount: _result?.total,
          initialDescription: _result?.merchantName,
          initialDate: _result?.date,
        ),
      ),
    );
  }
}

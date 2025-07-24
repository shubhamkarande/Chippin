import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../core/providers/simple_provider.dart';
import '../core/models/expense.dart';
import '../core/theme/app_theme.dart';

class AddExpenseScreen extends StatefulWidget {
  final String groupId;

  const AddExpenseScreen({super.key, required this.groupId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();

  String? _selectedPayer;
  String _splitType = 'equal';
  XFile? _receiptImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        actions: [
          TextButton(
            onPressed: _saveExpense,
            child: const Text('Save', style: TextStyle(color: AppTheme.white)),
          ),
        ],
      ),
      body: Consumer<SimpleProvider>(
        builder: (context, provider, child) {
          final group = provider.selectedGroup;
          if (group == null)
            return const Center(child: CircularProgressIndicator());

          final groupMembers = provider.members
              .where((member) => group.memberIds.contains(member.id))
              .toList();

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Receipt Image Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Receipt (Optional)',
                              style: AppTextStyles.heading2,
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      _pickImage(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _pickImage(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_library),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_receiptImage != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            height: 100,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.lightGray),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Receipt image selected',
                                    style: AppTextStyles.caption,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _receiptImage = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Basic Info
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What was this expense for?',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: '0.00',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _merchantController,
                  decoration: const InputDecoration(
                    labelText: 'Merchant (Optional)',
                    hintText: 'Where was this purchased?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Who Paid
                Text('Who paid?', style: AppTextStyles.heading2),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: _selectedPayer,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Select who paid'),
                  items: groupMembers.map((member) {
                    return DropdownMenuItem(
                      value: member.id,
                      child: Text(member.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPayer = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select who paid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Split Type
                Text('How to split?', style: AppTextStyles.heading2),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('Split equally'),
                        subtitle: Text('${groupMembers.length} people'),
                        value: 'equal',
                        groupValue: _splitType,
                        onChanged: (value) {
                          setState(() {
                            _splitType = value!;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Custom amounts'),
                        subtitle: const Text('Set individual amounts'),
                        value: 'custom',
                        groupValue: _splitType,
                        onChanged: (value) {
                          setState(() {
                            _splitType = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _receiptImage = image;
        });
        // TODO: Process OCR here
        _processReceiptOCR(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  void _processReceiptOCR(XFile image) {
    // TODO: Implement OCR processing
    // For now, just show a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OCR processing will be implemented')),
    );
  }

  void _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<SimpleProvider>();
    final group = provider.selectedGroup!;
    final groupMembers = provider.members
        .where((member) => group.memberIds.contains(member.id))
        .toList();

    final amount = double.parse(_amountController.text);
    final uuid = const Uuid();

    // Calculate splits
    List<ExpenseSplit> splits = [];
    if (_splitType == 'equal') {
      final splitAmount = amount / groupMembers.length;
      for (var member in groupMembers) {
        splits.add(ExpenseSplit(memberId: member.id, amount: splitAmount));
      }
    }

    final expense = Expense(
      id: uuid.v4(),
      groupId: widget.groupId,
      description: _descriptionController.text.trim(),
      amount: amount,
      paidBy: _selectedPayer!,
      splits: splits,
      createdAt: DateTime.now(),
      receiptImagePath: _receiptImage?.path,
      merchantName: _merchantController.text.trim().isEmpty
          ? null
          : _merchantController.text.trim(),
    );

    provider.addExpense(expense);

    if (mounted) {
      Navigator.pop(context);
    }
  }
}

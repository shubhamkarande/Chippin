import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../core/providers/simple_provider.dart';
import '../core/models/group.dart';
import '../core/models/member.dart';
import '../core/theme/app_theme.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<String> _memberEmails = [''];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        actions: [
          TextButton(
            onPressed: _createGroup,
            child: const Text(
              'Create',
              style: TextStyle(color: AppTheme.white),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g., Goa Trip, Roommates',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a group name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'What is this group for?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Add Members', style: AppTextStyles.heading2),
                TextButton.icon(
                  onPressed: _addMemberField,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ..._buildMemberFields(),
            const SizedBox(height: AppSpacing.lg),
            Card(
              color: AppTheme.lightGreen,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppTheme.darkGreen,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Group Features',
                          style: AppTextStyles.heading2.copyWith(
                            color: AppTheme.darkGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('• Split bills automatically'),
                    const Text('• Scan receipts with OCR'),
                    const Text('• Track who owes what'),
                    const Text('• Export summaries as PDF'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMemberFields() {
    return _memberEmails.asMap().entries.map((entry) {
      int index = entry.key;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: entry.value,
                decoration: InputDecoration(
                  labelText: 'Member ${index + 1} Email',
                  hintText: 'email@example.com',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (value) {
                  _memberEmails[index] = value;
                },
                validator: index == 0
                    ? null
                    : (value) {
                        if (value != null &&
                            value.isNotEmpty &&
                            !value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
              ),
            ),
            if (index > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: () => _removeMemberField(index),
                icon: const Icon(Icons.remove_circle, color: AppTheme.red),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  void _addMemberField() {
    setState(() {
      _memberEmails.add('');
    });
  }

  void _removeMemberField(int index) {
    setState(() {
      _memberEmails.removeAt(index);
    });
  }

  void _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<SimpleProvider>();
    final uuid = const Uuid();

    // Create group
    final group = Group(
      id: uuid.v4(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      createdAt: DateTime.now(),
      createdBy: 'current_user', // TODO: Replace with actual user ID
      memberIds: [],
      inviteCode: uuid.v4().substring(0, 8).toUpperCase(),
    );

    // Create members from emails
    List<String> memberIds = [];
    for (String email in _memberEmails) {
      if (email.trim().isNotEmpty) {
        final member = Member(
          id: uuid.v4(),
          name: email.split('@')[0], // Use email prefix as name for now
          email: email.trim(),
          joinedAt: DateTime.now(),
        );
        provider.addMember(member);
        memberIds.add(member.id);
      }
    }

    // Update group with member IDs
    final updatedGroup = Group(
      id: group.id,
      name: group.name,
      description: group.description,
      createdAt: group.createdAt,
      createdBy: group.createdBy,
      memberIds: memberIds,
      inviteCode: group.inviteCode,
    );

    provider.createGroup(updatedGroup);

    if (mounted) {
      Navigator.pop(context);
    }
  }
}

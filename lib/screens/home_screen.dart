import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/simple_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/models/group.dart';
import 'group_detail_screen.dart';
import 'create_group_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SimpleProvider>().loadGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chippin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // TODO: Profile/Settings
            },
          ),
        ],
      ),
      body: Consumer<SimpleProvider>(
        builder: (context, provider, child) {
          if (provider.groups.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: provider.groups.length,
            itemBuilder: (context, index) {
              final group = provider.groups[index];
              return _buildGroupCard(group, provider);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_add, size: 80, color: AppTheme.mediumGray),
          const SizedBox(height: AppSpacing.md),
          Text('No groups yet', style: AppTextStyles.heading2),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Create your first group to start splitting bills',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateGroupScreen(),
                ),
              );
            },
            child: const Text('Create Group'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(Group group, SimpleProvider provider) {
    final total = provider.getGroupTotal(group.id);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryGreen,
          child: Text(
            group.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(group.name, style: AppTextStyles.heading2),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(group.description, style: AppTextStyles.caption),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${group.memberIds.length} members • ₹${total.toStringAsFixed(2)} total',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupDetailScreen(groupId: group.id),
            ),
          );
        },
      ),
    );
  }
}

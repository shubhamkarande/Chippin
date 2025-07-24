import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/providers/simple_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/models/expense.dart';
import 'add_expense_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SimpleProvider>().selectGroup(widget.groupId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SimpleProvider>(
      builder: (context, provider, child) {
        final group = provider.selectedGroup;
        if (group == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(group.name),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Expenses'),
                Tab(text: 'Members'),
                Tab(text: 'Summary'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildExpensesTab(provider),
              _buildMembersTab(provider),
              _buildSummaryTab(provider),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddExpenseScreen(groupId: widget.groupId),
                ),
              );
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildExpensesTab(SimpleProvider provider) {
    final expenses = provider.selectedGroupExpenses;

    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: AppTheme.mediumGray),
            const SizedBox(height: AppSpacing.md),
            Text('No expenses yet', style: AppTextStyles.heading2),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add your first expense to get started',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];
        return _buildExpenseCard(expense, provider);
      },
    );
  }

  Widget _buildExpenseCard(Expense expense, SimpleProvider provider) {
    final paidByMember = provider.members.firstWhere(
      (m) => m.id == expense.paidBy,
      orElse: () => provider.members.first,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        leading: CircleAvatar(
          backgroundColor: AppTheme.blue,
          child: const Icon(Icons.receipt, color: AppTheme.white),
        ),
        title: Text(expense.description, style: AppTextStyles.heading2),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Text('Paid by ${paidByMember.name}', style: AppTextStyles.caption),
            Text(
              DateFormat('MMM dd, yyyy').format(expense.createdAt),
              style: AppTextStyles.caption,
            ),
            if (expense.merchantName != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'at ${expense.merchantName}',
                style: AppTextStyles.caption.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        trailing: Text(
          '₹${expense.amount.toStringAsFixed(2)}',
          style: AppTextStyles.heading2.copyWith(color: AppTheme.primaryGreen),
        ),
      ),
    );
  }

  Widget _buildMembersTab(SimpleProvider provider) {
    final group = provider.selectedGroup!;
    final groupMembers = provider.members
        .where((member) => group.memberIds.contains(member.id))
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: groupMembers.length,
      itemBuilder: (context, index) {
        final member = groupMembers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          child: ListTile(
            contentPadding: const EdgeInsets.all(AppSpacing.md),
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryGreen,
              child: Text(
                member.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: AppTheme.white),
              ),
            ),
            title: Text(member.name, style: AppTextStyles.heading2),
            subtitle: Text(member.email, style: AppTextStyles.caption),
          ),
        );
      },
    );
  }

  Widget _buildSummaryTab(SimpleProvider provider) {
    final balances = provider.getMemberBalances(widget.groupId);
    final total = provider.getGroupTotal(widget.groupId);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppTheme.lightGreen,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Group Spending', style: AppTextStyles.heading2),
                  Text(
                    '₹${total.toStringAsFixed(2)}',
                    style: AppTextStyles.heading1.copyWith(
                      color: AppTheme.darkGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Member Balances', style: AppTextStyles.heading2),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ListView.builder(
              itemCount: balances.length,
              itemBuilder: (context, index) {
                final memberId = balances.keys.elementAt(index);
                final balance = balances[memberId]!;
                final member = provider.members.firstWhere(
                  (m) => m.id == memberId,
                  orElse: () => provider.members.first,
                );

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: balance >= 0
                          ? AppTheme.primaryGreen
                          : AppTheme.orange,
                      child: Text(
                        member.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: AppTheme.white),
                      ),
                    ),
                    title: Text(member.name),
                    trailing: Text(
                      balance >= 0
                          ? '+₹${balance.toStringAsFixed(2)}'
                          : '-₹${(-balance).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: balance >= 0
                            ? AppTheme.primaryGreen
                            : AppTheme.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      balance >= 0 ? 'Gets back' : 'Owes',
                      style: AppTextStyles.caption,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

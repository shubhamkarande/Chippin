import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/group.dart';
import '../../models/balance.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/expense_card.dart';
import '../../widgets/balance_card.dart';
import '../expenses/add_expense_screen.dart';
import '../expenses/scan_receipt_screen.dart';
import '../summary/balance_summary_screen.dart';
import '../summary/export_screen.dart';
import '../summary/analytics_screen.dart';

/// Group detail screen with expenses and balances.
class GroupDetailScreen extends ConsumerStatefulWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadExpenses();
  }

  void _loadExpenses() {
    ref.read(expensesStateProvider.notifier).loadExpenses(widget.group.id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesState = ref.watch(expensesStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF312E81),
                            const Color(0xFF4338CA),
                          ]
                        : [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withBlue(255),
                          ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 60),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text('👥', style: TextStyle(fontSize: 28)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.group.name,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${widget.group.memberCount} members',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Total expenses summary
                      if (!expensesState.isLoading)
                        _buildQuickStats(expensesState),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: _showInviteDialog,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  switch (value) {
                    case 'analytics':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AnalyticsScreen(group: widget.group),
                        ),
                      );
                      break;
                    case 'export':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExportScreen(group: widget.group),
                        ),
                      );
                      break;
                    case 'settings':
                      // TODO: Group settings
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'analytics',
                    child: Row(
                      children: [
                        Icon(Icons.bar_chart, size: 20),
                        SizedBox(width: 12),
                        Text('Analytics'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.file_download_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Export'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Settings'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Expenses'),
                Tab(text: 'Balances'),
                Tab(text: 'Activity'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildExpensesTab(expensesState),
            _buildBalancesTab(expensesState),
            _buildActivityTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseOptions,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  Widget _buildQuickStats(ExpensesState state) {
    final total = state.expenses.fold(0.0, (sum, e) => sum + e.amount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '₹${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.white.withOpacity(0.3),
          ),
          Column(
            children: [
              Text(
                '${state.expenses.length}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Expenses',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTab(ExpensesState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.expenses.isEmpty) {
      return _buildEmptyExpenses();
    }

    return RefreshIndicator(
      onRefresh: () async => _loadExpenses(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.expenses.length,
        itemBuilder: (context, index) {
          final expense = state.expenses[index];
          return ExpenseCard(
            expense: expense,
            onTap: () {
              // TODO: Show expense details
            },
          ).animate(delay: Duration(milliseconds: index * 30)).fadeIn().slideX(
                begin: 0.05,
                end: 0,
              );
        },
      ),
    );
  }

  Widget _buildEmptyExpenses() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('💰', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No expenses yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first expense to get started',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBalancesTab(ExpensesState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final balances = state.balanceList;
    final debts = state.debtList;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Settlement summary
        if (debts.isNotEmpty) ...[
          const Text(
            'Settle Up',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...debts.map((debt) => _buildDebtCard(debt)),
          const SizedBox(height: 24),
        ],

        // Individual balances
        const Text(
          'Balances',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (balances.isEmpty)
          const Center(child: Text('No balances to show'))
        else
          ...balances.map((balance) => BalanceCard(balance: balance)),

        const SizedBox(height: 16),

        OutlinedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BalanceSummaryScreen(group: widget.group),
              ),
            );
          },
          child: const Text('View Full Summary'),
        ),
      ],
    );
  }

  Widget _buildDebtCard(SimplifiedDebt debt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.negativeBalance.withOpacity(0.1),
              child: Text(
                debt.fromUserName.isNotEmpty ? debt.fromUserName[0] : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.negativeBalance,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${debt.fromUserName} → ${debt.toUserName}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
            ),
            ElevatedButton(
              onPressed: () => _recordSettlement(debt),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
              ),
              child: const Text('Settle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTab() {
    return const Center(
      child: Text('Activity feed coming soon'),
    );
  }

  void _showAddExpenseOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: AppTheme.primaryColor,
                ),
              ),
              title: const Text(
                'Manual Entry',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Enter expense details'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddExpenseScreen(group: widget.group),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppTheme.secondaryColor,
                ),
              ),
              title: const Text(
                'Scan Receipt',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Use camera to scan'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScanReceiptScreen(group: widget.group),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Friends'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: widget.group.inviteCode,
                version: QrVersions.auto,
                size: 200,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.group.inviteCode,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: widget.group.inviteCode),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _recordSettlement(SimplifiedDebt debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Settlement'),
        content: Text(
          'Mark ₹${debt.amount.toStringAsFixed(2)} as paid from ${debt.fromUserName} to ${debt.toUserName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final user = ref.read(authStateProvider).user;
      if (user == null) return;

      await ref.read(expensesStateProvider.notifier).createSettlement(
            groupId: widget.group.id,
            fromUserId: debt.fromUserId,
            toUserId: debt.toUserId,
            amount: debt.amount,
            createdById: user.id,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settlement recorded!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }
}

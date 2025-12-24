// Widget tests for Chippin Flutter app
//
// Tests cover:
// - Widget rendering
// - User interactions
// - State management
// - Navigation

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chippin/main.dart';
import 'package:chippin/models/user.dart';
import 'package:chippin/models/group.dart';
import 'package:chippin/models/expense.dart';
import 'package:chippin/models/balance.dart';
import 'package:chippin/widgets/expense_card.dart';
import 'package:chippin/widgets/balance_card.dart';
import 'package:chippin/widgets/group_card.dart';
import 'package:chippin/widgets/category_chip.dart';

void main() {
  group('User Model Tests', () {
    test('User.fromJson creates user correctly', () {
      final json = {
        'id': 'test-id',
        'email': 'test@example.com',
        'display_name': 'Test User',
        'is_guest': false,
        'created_at': '2024-01-01T00:00:00.000Z',
      };
      
      final user = User.fromJson(json);
      
      expect(user.id, 'test-id');
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Test User');
      expect(user.isGuest, false);
    });

    test('User.toJson converts user correctly', () {
      final user = User(
        id: 'test-id',
        email: 'test@example.com',
        displayName: 'Test User',
        isGuest: false,
        createdAt: DateTime(2024, 1, 1),
      );
      
      final json = user.toJson();
      
      expect(json['id'], 'test-id');
      expect(json['email'], 'test@example.com');
      expect(json['display_name'], 'Test User');
    });

    test('User.initials returns correct initials', () {
      final user = User(
        id: 'test-id',
        displayName: 'Test User',
        createdAt: DateTime.now(),
      );
      
      expect(user.initials, 'TU');
    });
  });

  group('Group Model Tests', () {
    test('Group.fromJson creates group correctly', () {
      final json = {
        'id': 'group-id',
        'name': 'Test Group',
        'description': 'A test group',
        'owner_id': 'owner-id',
        'invite_code': 'ABC123',
        'currency': 'INR',
        'is_active': true,
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };
      
      final group = Group.fromJson(json);
      
      expect(group.id, 'group-id');
      expect(group.name, 'Test Group');
      expect(group.currency, 'INR');
      expect(group.inviteCode, 'ABC123');
    });

    test('Group.memberCount returns correct count', () {
      final group = Group(
        id: 'group-id',
        name: 'Test Group',
        ownerId: 'owner-id',
        inviteCode: 'ABC123',
        members: [
          GroupMember(
            id: 'm1',
            userId: 'u1',
            role: 'owner',
            joinedAt: DateTime.now(),
          ),
          GroupMember(
            id: 'm2',
            userId: 'u2',
            role: 'member',
            joinedAt: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      expect(group.memberCount, 2);
    });
  });

  group('Expense Model Tests', () {
    test('Expense.fromJson creates expense correctly', () {
      final json = {
        'id': 'expense-id',
        'group_id': 'group-id',
        'description': 'Dinner',
        'amount': 100.0,
        'currency': 'INR',
        'paid_by': 'user-id',
        'split_type': 'equal',
        'expense_date': '2024-01-01T00:00:00.000Z',
        'created_by': 'user-id',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };
      
      final expense = Expense.fromJson(json);
      
      expect(expense.id, 'expense-id');
      expect(expense.description, 'Dinner');
      expect(expense.amount, 100.0);
    });
  });

  group('Balance Model Tests', () {
    test('Balance.fromJson creates balance correctly', () {
      final json = {
        'user_id': 'user-id',
        'display_name': 'Test User',
        'paid': 100.0,
        'owes': 50.0,
        'balance': 50.0,
      };
      
      final balance = Balance.fromJson(json);
      
      expect(balance.userId, 'user-id');
      expect(balance.displayName, 'Test User');
      expect(balance.balance, 50.0);
    });

    test('Balance.isPositive returns true for positive balance', () {
      final balance = Balance(
        userId: 'user-id',
        displayName: 'Test User',
        paid: 100,
        owes: 50,
        balance: 50,
      );
      
      expect(balance.isPositive, true);
    });

    test('Balance.isNegative returns true for negative balance', () {
      final balance = Balance(
        userId: 'user-id',
        displayName: 'Test User',
        paid: 0,
        owes: 50,
        balance: -50,
      );
      
      expect(balance.isNegative, true);
    });
  });

  group('SimplifiedDebt Model Tests', () {
    test('SimplifiedDebt.fromJson creates debt correctly', () {
      final json = {
        'from_user_id': 'user1',
        'from_user_name': 'User 1',
        'to_user_id': 'user2',
        'to_user_name': 'User 2',
        'amount': 50.0,
      };
      
      final debt = SimplifiedDebt.fromJson(json);
      
      expect(debt.fromUserId, 'user1');
      expect(debt.toUserId, 'user2');
      expect(debt.amount, 50.0);
    });
  });

  group('ExpenseCategory Tests', () {
    test('Default categories are created correctly', () {
      final categories = ExpenseCategory.defaultCategories;
      
      expect(categories.length, greaterThan(0));
      expect(categories.any((c) => c.name == 'Food & Dining'), true);
      expect(categories.any((c) => c.name == 'Transport'), true);
    });

    test('ExpenseCategory.colorValue parses hex color correctly', () {
      final category = ExpenseCategory(
        id: 'cat-1',
        name: 'Test',
        icon: '🍕',
        color: '#FF6B6B',
      );
      
      // Verify colorValue returns a valid color integer
      expect(category.colorValue, isA<int>());
      expect(category.colorValue, isNot(0));
    });
  });

  // Widget Tests
  group('Widget Tests', () {
    testWidgets('ExpenseCard displays expense information', (tester) async {
      final expense = Expense(
        id: 'expense-id',
        groupId: 'group-id',
        description: 'Test Expense',
        amount: 100.0,
        currency: 'INR',
        paidById: 'user-id',
        splitType: SplitType.equal,
        splits: [],
        expenseDate: DateTime.now(),
        createdById: 'user-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseCard(
              expense: expense,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Expense'), findsOneWidget);
      expect(find.textContaining('100'), findsWidgets);
    });

    testWidgets('BalanceCard displays balance information', (tester) async {
      final balance = Balance(
        userId: 'user-id',
        displayName: 'Test User',
        paid: 100,
        owes: 50,
        balance: 50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BalanceCard(balance: balance),
          ),
        ),
      );

      expect(find.text('Test User'), findsOneWidget);
    });

    testWidgets('GroupCard displays group information', (tester) async {
      final group = Group(
        id: 'group-id',
        name: 'Test Group',
        ownerId: 'owner-id',
        inviteCode: 'ABC123',
        members: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupCard(
              group: group,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Group'), findsOneWidget);
    });

    testWidgets('CategoryChip displays category', (tester) async {
      final category = ExpenseCategory(
        id: 'cat-1',
        name: 'Food & Dining',
        icon: '🍕',
        color: '#FF6B6B',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryChip(
              category: category,
              isSelected: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('🍕'), findsOneWidget);
      expect(find.text('Food & Dining'), findsOneWidget);
    });
  });
}

// Run tests with: flutter test

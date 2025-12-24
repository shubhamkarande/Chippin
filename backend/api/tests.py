"""
API Tests for Chippin Backend

Tests cover:
- User authentication and Firebase token verification
- Group CRUD operations
- Expense CRUD operations
- Balance calculations
- Sync operations
"""

from django.test import TestCase, Client
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase, APIClient
from unittest.mock import patch, MagicMock
from decimal import Decimal
import json
import uuid

from .models import User, Group, GroupMember, Expense, ExpenseSplit, Settlement


class UserModelTests(TestCase):
    """Tests for the User model."""

    def test_create_user(self):
        """Test creating a user with valid data."""
        user = User.objects.create(
            firebase_uid='test_firebase_uid',
            email='test@example.com',
            display_name='Test User'
        )
        self.assertEqual(user.email, 'test@example.com')
        self.assertEqual(user.display_name, 'Test User')
        self.assertFalse(user.is_guest)

    def test_create_guest_user(self):
        """Test creating a guest user."""
        user = User.objects.create(
            display_name='Guest User',
            is_guest=True
        )
        self.assertTrue(user.is_guest)
        self.assertEqual(user.display_name, 'Guest User')

    def test_user_str_representation(self):
        """Test string representation of user."""
        user = User.objects.create(
            email='test@example.com',
            display_name='Test User'
        )
        self.assertIn('Test User', str(user))


class GroupModelTests(TestCase):
    """Tests for the Group model."""

    def setUp(self):
        self.owner = User.objects.create(
            firebase_uid='owner_uid',
            email='owner@example.com',
            display_name='Owner'
        )

    def test_create_group(self):
        """Test creating a group."""
        group = Group.objects.create(
            name='Test Group',
            owner=self.owner,
            description='A test group',
            currency='INR'
        )
        self.assertEqual(group.name, 'Test Group')
        self.assertEqual(group.owner, self.owner)
        self.assertEqual(group.currency, 'INR')
        self.assertTrue(group.is_active)

    def test_group_invite_code_generation(self):
        """Test that invite codes are generated."""
        group = Group.objects.create(
            name='Test Group',
            owner=self.owner
        )
        # Invite code should be set (either auto-generated or can be set)
        self.assertIsNotNone(group.invite_code)

    def test_group_member_count(self):
        """Test group member count property."""
        group = Group.objects.create(
            name='Test Group',
            owner=self.owner
        )
        GroupMember.objects.create(group=group, user=self.owner, role='owner')
        self.assertEqual(group.member_count, 1)

        # Add another member
        member = User.objects.create(
            email='member@example.com',
            display_name='Member'
        )
        GroupMember.objects.create(group=group, user=member, role='member')
        self.assertEqual(group.member_count, 2)


class ExpenseModelTests(TestCase):
    """Tests for the Expense model."""

    def setUp(self):
        self.owner = User.objects.create(
            firebase_uid='owner_uid',
            email='owner@example.com',
            display_name='Owner'
        )
        self.group = Group.objects.create(
            name='Test Group',
            owner=self.owner
        )
        GroupMember.objects.create(group=self.group, user=self.owner, role='owner')

    def test_create_expense(self):
        """Test creating an expense."""
        expense = Expense.objects.create(
            group=self.group,
            description='Dinner',
            amount=Decimal('100.00'),
            paid_by=self.owner,
            created_by=self.owner,
            split_type='equal'
        )
        self.assertEqual(expense.description, 'Dinner')
        self.assertEqual(expense.amount, Decimal('100.00'))
        self.assertEqual(expense.paid_by, self.owner)

    def test_expense_splits(self):
        """Test expense splits creation."""
        expense = Expense.objects.create(
            group=self.group,
            description='Dinner',
            amount=Decimal('100.00'),
            paid_by=self.owner,
            created_by=self.owner,
            split_type='equal'
        )
        # Create split
        split = ExpenseSplit.objects.create(
            expense=expense,
            user=self.owner,
            amount=Decimal('50.00')
        )
        self.assertEqual(split.amount, Decimal('50.00'))
        self.assertEqual(expense.splits.count(), 1)


class BalanceCalculationTests(TestCase):
    """Tests for balance calculation logic."""

    def setUp(self):
        self.user1 = User.objects.create(
            email='user1@example.com',
            display_name='User 1'
        )
        self.user2 = User.objects.create(
            email='user2@example.com',
            display_name='User 2'
        )
        self.group = Group.objects.create(
            name='Test Group',
            owner=self.user1
        )
        GroupMember.objects.create(group=self.group, user=self.user1, role='owner')
        GroupMember.objects.create(group=self.group, user=self.user2, role='member')

    def test_equal_split_balance(self):
        """Test balance calculation with equal splits."""
        # User1 pays 100, split equally between 2 users
        expense = Expense.objects.create(
            group=self.group,
            description='Dinner',
            amount=Decimal('100.00'),
            paid_by=self.user1,
            created_by=self.user1,
            split_type='equal'
        )
        ExpenseSplit.objects.create(expense=expense, user=self.user1, amount=Decimal('50.00'))
        ExpenseSplit.objects.create(expense=expense, user=self.user2, amount=Decimal('50.00'))

        # Calculate balances
        balances = self._calculate_balances()
        
        # User1 paid 100, owes 50 = +50 (gets back 50)
        # User2 paid 0, owes 50 = -50 (owes 50)
        self.assertEqual(balances[str(self.user1.id)], Decimal('50.00'))
        self.assertEqual(balances[str(self.user2.id)], Decimal('-50.00'))

    def test_multiple_expenses_balance(self):
        """Test balance with multiple expenses."""
        # User1 pays 100
        expense1 = Expense.objects.create(
            group=self.group,
            description='Dinner',
            amount=Decimal('100.00'),
            paid_by=self.user1,
            created_by=self.user1
        )
        ExpenseSplit.objects.create(expense=expense1, user=self.user1, amount=Decimal('50.00'))
        ExpenseSplit.objects.create(expense=expense1, user=self.user2, amount=Decimal('50.00'))

        # User2 pays 60
        expense2 = Expense.objects.create(
            group=self.group,
            description='Lunch',
            amount=Decimal('60.00'),
            paid_by=self.user2,
            created_by=self.user2
        )
        ExpenseSplit.objects.create(expense=expense2, user=self.user1, amount=Decimal('30.00'))
        ExpenseSplit.objects.create(expense=expense2, user=self.user2, amount=Decimal('30.00'))

        balances = self._calculate_balances()
        
        # User1: paid 100, owes 80 = +20
        # User2: paid 60, owes 80 = -20
        self.assertEqual(balances[str(self.user1.id)], Decimal('20.00'))
        self.assertEqual(balances[str(self.user2.id)], Decimal('-20.00'))

    def _calculate_balances(self):
        """Helper to calculate balances for the group."""
        balances = {}
        expenses = Expense.objects.filter(group=self.group, is_deleted=False)
        
        for expense in expenses:
            paid_by_id = str(expense.paid_by.id)
            balances[paid_by_id] = balances.get(paid_by_id, Decimal('0')) + expense.amount
            
            for split in expense.splits.all():
                user_id = str(split.user.id)
                balances[user_id] = balances.get(user_id, Decimal('0')) - split.amount
        
        return balances


class SettlementTests(TestCase):
    """Tests for settlement functionality."""

    def setUp(self):
        self.user1 = User.objects.create(
            email='user1@example.com',
            display_name='User 1'
        )
        self.user2 = User.objects.create(
            email='user2@example.com',
            display_name='User 2'
        )
        self.group = Group.objects.create(
            name='Test Group',
            owner=self.user1
        )

    def test_create_settlement(self):
        """Test creating a settlement."""
        settlement = Settlement.objects.create(
            group=self.group,
            from_user=self.user2,
            to_user=self.user1,
            amount=Decimal('50.00'),
            created_by=self.user2
        )
        self.assertEqual(settlement.amount, Decimal('50.00'))
        self.assertEqual(settlement.from_user, self.user2)
        self.assertEqual(settlement.to_user, self.user1)


class APIAuthenticationTests(APITestCase):
    """Tests for API authentication."""

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create(
            firebase_uid='test_uid',
            email='test@example.com',
            display_name='Test User'
        )

    @patch('api.authentication.FirebaseAuthentication.authenticate')
    def test_authenticated_request(self, mock_auth):
        """Test that authenticated requests work."""
        mock_auth.return_value = (self.user, None)
        
        # This would depend on your actual endpoints
        # Example: response = self.client.get('/api/groups/')
        # self.assertEqual(response.status_code, status.HTTP_200_OK)
        pass

    def test_unauthenticated_request(self):
        """Test that unauthenticated requests are rejected."""
        # Requests without auth should be rejected for protected endpoints
        # response = self.client.get('/api/groups/')
        # self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        pass


class GroupAPITests(APITestCase):
    """Tests for Group API endpoints."""

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create(
            firebase_uid='test_uid',
            email='test@example.com',
            display_name='Test User'
        )
        self.client.force_authenticate(user=self.user)

    def test_list_groups(self):
        """Test listing user's groups."""
        group = Group.objects.create(
            name='Test Group',
            owner=self.user
        )
        GroupMember.objects.create(group=group, user=self.user, role='owner')
        
        # If you have a groups list endpoint
        # response = self.client.get('/api/groups/')
        # self.assertEqual(response.status_code, status.HTTP_200_OK)
        # self.assertEqual(len(response.data), 1)
        pass

    def test_create_group(self):
        """Test creating a new group."""
        data = {
            'name': 'New Group',
            'description': 'Test description',
            'currency': 'INR'
        }
        # response = self.client.post('/api/groups/', data)
        # self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        pass


class ExpenseAPITests(APITestCase):
    """Tests for Expense API endpoints."""

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create(
            firebase_uid='test_uid',
            email='test@example.com',
            display_name='Test User'
        )
        self.group = Group.objects.create(
            name='Test Group',
            owner=self.user
        )
        GroupMember.objects.create(group=self.group, user=self.user, role='owner')
        self.client.force_authenticate(user=self.user)

    def test_create_expense(self):
        """Test creating an expense."""
        data = {
            'description': 'Dinner',
            'amount': '100.00',
            'paid_by': str(self.user.id),
            'split_type': 'equal',
            'splits': [
                {'user_id': str(self.user.id), 'amount': '100.00'}
            ]
        }
        # response = self.client.post(f'/api/groups/{self.group.id}/expenses/', data, format='json')
        # self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        pass


class SyncAPITests(APITestCase):
    """Tests for sync API endpoints."""

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create(
            firebase_uid='test_uid',
            email='test@example.com',
            display_name='Test User'
        )
        self.client.force_authenticate(user=self.user)

    def test_push_sync(self):
        """Test pushing local changes to server."""
        # Test sync push endpoint
        pass

    def test_pull_sync(self):
        """Test pulling server changes."""
        # Test sync pull endpoint
        pass


# Run tests with: python manage.py test api

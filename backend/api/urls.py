"""
URL configuration for Chippin API.
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter

from api.views.auth_views import VerifyTokenView, GuestLoginView, CurrentUserView
from api.views.group_views import GroupViewSet
from api.views.expense_views import ExpenseViewSet, SettlementViewSet, CategoryViewSet
from api.views.sync_views import SyncPushView, SyncPullView


# Create router and register viewsets
router = DefaultRouter()
router.register(r'groups', GroupViewSet, basename='group')
router.register(r'expenses', ExpenseViewSet, basename='expense')
router.register(r'settlements', SettlementViewSet, basename='settlement')
router.register(r'categories', CategoryViewSet, basename='category')

urlpatterns = [
    # Auth endpoints
    path('auth/verify', VerifyTokenView.as_view(), name='auth-verify'),
    path('auth/guest', GuestLoginView.as_view(), name='auth-guest'),
    path('auth/me', CurrentUserView.as_view(), name='auth-me'),

    # Sync endpoints
    path('sync/push', SyncPushView.as_view(), name='sync-push'),
    path('sync/pull', SyncPullView.as_view(), name='sync-pull'),

    # Router URLs
    path('', include(router.urls)),
]

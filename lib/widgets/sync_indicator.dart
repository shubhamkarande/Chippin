import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sync_service.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Widget showing sync status indicator.
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: _buildIndicator(syncStatus, pendingCount),
    );
  }

  Widget _buildIndicator(SyncStatus status, AsyncValue<int> pendingCount) {
    switch (status) {
      case SyncStatus.syncing:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Syncing',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        );

      case SyncStatus.error:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 14,
                color: AppTheme.errorColor,
              ),
              const SizedBox(width: 4),
              const Text(
                'Sync error',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.errorColor,
                ),
              ),
            ],
          ),
        );

      case SyncStatus.offline:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off,
                size: 14,
                color: AppTheme.warningColor,
              ),
              const SizedBox(width: 4),
              const Text(
                'Offline',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.warningColor,
                ),
              ),
            ],
          ),
        );

      case SyncStatus.success:
      case SyncStatus.idle:
        return pendingCount.when(
          data: (count) {
            if (count > 0) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_upload,
                      size: 14,
                      color: AppTheme.warningColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$count pending',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
    }
  }
}

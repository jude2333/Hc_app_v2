import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/users_providers.dart';
import 'user_mobile_card.dart';
import 'users_pagination.dart';
import '../../theme/theme.dart';

class UsersMobileList extends ConsumerWidget {
  const UsersMobileList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersListProvider);

    return Column(
      children: [
        Expanded(
          child: usersAsync.when(
            data: (users) {
              if (users.isEmpty) {
                return _buildEmptyState();
              }
              return ListView.builder(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  return UserMobileCard(user: users[index]);
                },
              );
            },
            loading: () => _buildLoadingState(),
            error: (err, stack) => _buildErrorState(err.toString()),
          ),
        ),
        const UsersPagination(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: 48,
              color: AppColors.textHint,
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          Text('No users found', style: AppTextStyles.h3),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Try adjusting your search',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: AppSpacing.md),
          Text('Loading users...', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: 48, color: AppColors.error),
          ),
          SizedBox(height: AppSpacing.lg),
          Text('Failed to load', style: AppTextStyles.h3),
          SizedBox(height: AppSpacing.sm),
          Text(error, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/user_model.dart';
import '../providers/users_providers.dart';
import 'users_table_row.dart';
import 'users_pagination.dart';
import '../../theme/theme.dart';

class UsersDesktopTable extends ConsumerWidget {
  const UsersDesktopTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersListProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.lgAll,
        child: Column(
          children: [
            Expanded(
              child: usersAsync.when(
                data: (users) {
                  if (users.isEmpty) {
                    return _buildEmptyState();
                  }
                  return UsersTableContent(users: users);
                },
                loading: () => _buildLoadingState(),
                error: (err, stack) => _buildErrorState(err.toString()),
              ),
            ),
            const UsersPagination(),
          ],
        ),
      ),
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
            'Try adjusting your search or add a new user',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        // Skeleton header
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 1),
            ),
          ),
          child: Row(
            children: List.generate(
                6,
                (i) => Expanded(
                      flex: i == 0 || i == 2 ? 3 : 2,
                      child: _SkeletonBox(width: 60, height: 14),
                    )),
          ),
        ),
        // Skeleton rows
        Expanded(
          child: ListView.builder(
            itemCount: 8,
            itemBuilder: (context, index) => _SkeletonTableRow(),
          ),
        ),
      ],
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
          Text('Failed to load users', style: AppTextStyles.h3),
          SizedBox(height: AppSpacing.sm),
          Text(error, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class UsersTableContent extends StatelessWidget {
  final List<User> users;

  const UsersTableContent({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.05),
                AppColors.primary.withOpacity(0.02),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 1),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                _buildHeaderCell('Name', flex: 3, icon: Icons.person_outline),
                _buildHeaderCell('Mobile', flex: 2, icon: Icons.phone_outlined),
                _buildHeaderCell('Role', flex: 3, icon: Icons.badge_outlined),
                _buildHeaderCell('Department',
                    flex: 2, icon: Icons.business_outlined),
                _buildHeaderCell('ID Card',
                    flex: 2, icon: Icons.credit_card_outlined),
                _buildHeaderCell('Actions', flex: 2, centered: true),
                _buildHeaderCell('', flex: 1, centered: true),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return UserTableRow(user: user, index: index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(
    String text, {
    required int flex,
    bool centered = false,
    IconData? icon,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          mainAxisAlignment:
              centered ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.primary),
              SizedBox(width: AppSpacing.xs),
            ],
            Text(
              text,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper widgets for Skeleton Loading
class _SkeletonTableRow extends StatefulWidget {
  @override
  State<_SkeletonTableRow> createState() => _SkeletonTableRowState();
}

class _SkeletonTableRowState extends State<_SkeletonTableRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: FadeTransition(
        opacity: _animation,
        child: Row(
          children: [
            Expanded(flex: 3, child: _SkeletonBox(width: 120, height: 16)),
            Expanded(flex: 2, child: _SkeletonBox(width: 100, height: 16)),
            Expanded(flex: 3, child: _SkeletonBox(width: 80, height: 16)),
            Expanded(flex: 2, child: _SkeletonBox(width: 100, height: 16)),
            Expanded(flex: 2, child: _SkeletonBox(width: 60, height: 24)),
            Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SkeletonBox(width: 24, height: 24, isCircle: true),
                    SizedBox(width: AppSpacing.sm),
                    _SkeletonBox(width: 24, height: 24, isCircle: true),
                  ],
                )),
            Expanded(flex: 1, child: SizedBox()),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final bool isCircle;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: isCircle ? null : AppRadius.smAll,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/users_providers.dart';
import '../../theme/theme.dart';

class UsersPagination extends ConsumerWidget {
  const UsersPagination({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagination = ref.watch(usersPaginationProvider);
    final usersAsync = ref.watch(usersListProvider);

    final currentCount = usersAsync.value?.length ?? 0;
    final isFullPage =
        currentCount >= pagination.rowsPerPage && pagination.rowsPerPage != -1;

    final startItem = (pagination.page - 1) * pagination.rowsPerPage + 1;
    final endItem = startItem + currentCount - 1;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('Rows:', style: AppTextStyles.caption),
              SizedBox(width: AppSpacing.sm),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: AppRadius.smAll,
                ),
                child: DropdownButton<int>(
                  value: pagination.rowsPerPage,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  style: AppTextStyles.body,
                  items: [50, 70, 100, -1].map((value) {
                    return DropdownMenuItem(
                      value: value,
                      child: Text(
                        value == -1 ? 'All' : value.toString(),
                        style: AppTextStyles.body,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(usersPaginationProvider.notifier)
                          .setRowsPerPage(value);
                    }
                  },
                ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: AppRadius.smAll,
            ),
            child: Text(
              pagination.rowsPerPage == -1
                  ? '$currentCount users'
                  : '$startItem-$endItem',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: pagination.page > 1
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.surfaceAlt,
                  borderRadius: AppRadius.smAll,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.chevron_left,
                    color: pagination.page > 1
                        ? AppColors.primary
                        : AppColors.textHint,
                  ),
                  onPressed: pagination.page > 1
                      ? () {
                          ref
                              .read(usersPaginationProvider.notifier)
                              .setPage(pagination.page - 1);
                        }
                      : null,
                  tooltip: 'Previous page',
                  iconSize: 20,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: AppRadius.smAll,
                ),
                child: Text(
                  'Page ${pagination.page}',
                  style:
                      AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: isFullPage
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.surfaceAlt,
                  borderRadius: AppRadius.smAll,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    color: isFullPage ? AppColors.primary : AppColors.textHint,
                  ),
                  onPressed: isFullPage
                      ? () {
                          ref
                              .read(usersPaginationProvider.notifier)
                              .setPage(pagination.page + 1);
                        }
                      : null,
                  tooltip: 'Next page',
                  iconSize: 20,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

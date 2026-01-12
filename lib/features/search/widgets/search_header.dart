import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';

/// Search page header with title chip
class SearchHeader extends StatelessWidget {
  const SearchHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: AppPadding.badge,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: AppRadius.smAll,
            ),
            child: Text(
              'Search HC Patients',
              style: AppTextStyles.badge.copyWith(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

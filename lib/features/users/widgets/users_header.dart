import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Header widget for the Users page with search and add button.
class UsersHeader extends StatelessWidget {
  final TextEditingController searchController;
  final Function(String) onSearchChanged;
  final VoidCallback onAddUser;

  const UsersHeader({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onAddUser,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppSizes.cardElevation,
      color: AppColors.surface,
      child: Padding(
        padding: AppPadding.card,
        child: Row(
          children: [
            Container(
              padding: AppPadding.badge,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.lgAll,
              ),
              child: Text(
                'Users',
                style: AppTextStyles.badge,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: AppSizes.searchFieldWidth,
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.mdAll,
                  ),
                  contentPadding: AppPadding.input,
                ),
                onChanged: onSearchChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: AppPadding.button,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.mdAll,
                ),
              ),
              onPressed: onAddUser,
            ),
          ],
        ),
      ),
    );
  }
}

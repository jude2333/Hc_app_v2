import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Header widget for the Users page with search and add button.
/// Responsive: stacks vertically on mobile, horizontal on desktop.
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Card(
      elevation: AppSizes.cardElevation,
      color: AppColors.surface,
      child: Padding(
        padding: AppPadding.card,
        child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        _buildTitleBadge(),
        const Spacer(),
        _buildSearchField(width: AppSizes.searchFieldWidth),
        const SizedBox(width: AppSpacing.lg),
        _buildAddButton(showLabel: true),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _buildTitleBadge(),
            const Spacer(),
            _buildAddButton(showLabel: false),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _buildSearchField(width: null),
      ],
    );
  }

  Widget _buildTitleBadge() {
    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.lgAll,
      ),
      child: Text(
        'Users',
        style: AppTextStyles.badge,
      ),
    );
  }

  Widget _buildSearchField({double? width}) {
    return SizedBox(
      width: width,
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
    );
  }

  Widget _buildAddButton({required bool showLabel}) {
    if (showLabel) {
      return ElevatedButton.icon(
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
      );
    }

    // Icon-only button for mobile
    return IconButton(
      icon: const Icon(Icons.person_add_outlined),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      onPressed: onAddUser,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import '../providers/search_provider.dart';
import '../widgets/search_header.dart';
import '../widgets/search_bar_panel.dart';
import '../widgets/search_skeleton.dart';
import '../widgets/search_mobile_view.dart';
import '../widgets/search_desktop_table.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchProvider.notifier).clearResults();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final state = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SearchHeader(),
          const SearchBarPanel(),
          SizedBox(height: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _buildContent(state, isMobile),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(SearchState state, bool isMobile) {
    if (state.isLoading) {
      return SearchSkeleton(isMobile: isMobile);
    }

    if (state.error != null && state.results.isEmpty) {
      return _buildMessageState(
        icon: Icons.info_outline,
        iconColor: state.error!.contains('No data')
            ? AppColors.textHint
            : AppColors.primary,
        message: state.error!,
      );
    }

    if (state.results.isEmpty) {
      return _buildEmptyState();
    }

    return isMobile
        ? SearchMobileView(results: state.results)
        : SearchDesktopTable(results: state.results);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_rounded,
            size: 80,
            color: AppColors.primary.withOpacity(0.5),
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Search HC Patients',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Enter a mobile number, select a date, or type a name',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHintChip(Icons.phone, 'Mobile'),
              SizedBox(width: AppSpacing.md),
              _buildHintChip(Icons.calendar_today, 'Date'),
              SizedBox(width: AppSpacing.md),
              _buildHintChip(Icons.person, 'Name'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHintChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withOpacity(0.5),
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required Color iconColor,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: iconColor),
          SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => ref.read(searchProvider.notifier).search(),
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

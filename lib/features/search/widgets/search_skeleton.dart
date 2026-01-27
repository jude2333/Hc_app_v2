import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';

class SearchSkeleton extends StatelessWidget {
  final bool isMobile;

  const SearchSkeleton({super.key, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return isMobile ? _buildMobileSkeleton() : _buildDesktopSkeleton();
  }

  Widget _buildMobileSkeleton() {
    return ListView.builder(
      padding: EdgeInsets.all(AppSpacing.md),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          margin: EdgeInsets.only(bottom: AppSpacing.md),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          child: Padding(
            padding: AppPadding.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _shimmerBox(width: 140, height: 18),
                    const Spacer(),
                    _shimmerBox(width: 70, height: 24, borderRadius: 12),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                _shimmerBox(width: 200, height: 14),
                SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _shimmerBox(width: 100, height: 12),
                    SizedBox(width: AppSpacing.md),
                    _shimmerBox(width: 80, height: 12),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _shimmerBox(width: 60, height: 22, borderRadius: 11),
                    SizedBox(width: AppSpacing.sm),
                    _shimmerBox(width: 80, height: 22, borderRadius: 11),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopSkeleton() {
    return Card(
      elevation: AppSizes.cardElevation,
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      child: Column(
        children: [
          Container(
            padding: AppPadding.tableCell,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: List.generate(
                8,
                (index) => Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.tableBorder,
                      borderRadius: AppRadius.xsAll,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 8,
              itemBuilder: (context, index) {
                return Container(
                  padding: AppPadding.tableCell,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.divider),
                    ),
                  ),
                  child: Row(
                    children: List.generate(
                      8,
                      (i) => Expanded(
                        child: Container(
                          margin:
                              EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.tableBorder,
                            borderRadius: AppRadius.xsAll,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox({
    required double width,
    required double height,
    double borderRadius = 4,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.tableBorder,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

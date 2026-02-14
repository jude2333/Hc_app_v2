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
      itemCount: 8,
      itemBuilder: (context, index) {
        return Card(
          margin: EdgeInsets.only(bottom: AppSpacing.md),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: AppRadius.mdAll,
              side: BorderSide(color: Colors.grey.shade200)),
          color: Colors.white,
          child: Padding(
            padding: AppPadding.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 20,
                      height: 20,
                      color: Colors.grey.shade100,
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Container(
                        width: 14, height: 14, color: Colors.grey.shade200),
                    SizedBox(width: 4),
                    Container(
                        width: 80, height: 14, color: Colors.grey.shade100),
                    SizedBox(width: AppSpacing.md),
                    Container(
                        width: 14, height: 14, color: Colors.grey.shade200),
                    SizedBox(width: 4),
                    Container(
                        width: 100, height: 14, color: Colors.grey.shade100),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 80,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                    ),
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
    final flexFactors = [1, 4, 2, 1, 3, 3, 2, 3, 3, 4, 2];

    return Card(
      elevation: 4,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
            ),
            child: Row(
              children: flexFactors
                  .map((flex) => Expanded(
                        flex: flex,
                        child: Container(
                          height: 16,
                          margin: EdgeInsets.only(right: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: 15,
              separatorBuilder: (ctx, i) =>
                  Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md, // Match table row padding roughly
                  ),
                  child: Row(
                    children: flexFactors
                        .map((flex) => Expanded(
                              flex: flex,
                              child: Container(
                                height: 14,
                                margin: EdgeInsets.only(right: AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

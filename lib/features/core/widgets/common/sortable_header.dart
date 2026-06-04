import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';

/// Sortable header cell for virtual work order tables.
/// Callback-based design to keep Riverpod logic in pages.
class SortableHeader extends StatelessWidget {
  final String label;
  final String sortKey;
  final int flex;
  final String currentSortColumn;
  final bool isAscending;
  final ValueChanged<String> onSort;

  const SortableHeader({
    super.key,
    required this.label,
    required this.sortKey,
    required this.flex,
    required this.currentSortColumn,
    required this.isAscending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentSortColumn == sortKey;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // Non-sortable header (empty sortKey)
    if (sortKey.isEmpty) {
      return Expanded(
        flex: flex,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      );
    }

    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => onSort(sortKey),
        child: Padding(
          padding: AppPadding.custom,
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? (isDark ? AppColors.gradientEnd : AppColors.primary)
                      : colorScheme.onSurface,
                ),
              ),
              if (isActive)
                Icon(
                  isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: isDark ? AppColors.gradientEnd : AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple non-sortable header cell (for consistency).
class HeaderCell extends StatelessWidget {
  final String text;
  final int flex;

  const HeaderCell(this.text, {super.key, required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: AppPadding.custom,
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

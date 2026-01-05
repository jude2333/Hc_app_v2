import 'package:flutter/material.dart';

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

    // Non-sortable header (empty sortKey)
    if (sortKey.isEmpty) {
      return Expanded(
        flex: flex,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }

    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => onSort(sortKey),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.orange : Colors.black,
                ),
              ),
              if (isActive)
                Icon(
                  isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: Colors.orange,
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:anderson_crm_flutter/features/price_list/price_list.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';

class HistorySheet extends ConsumerStatefulWidget {
  const HistorySheet({Key? key}) : super(key: key);

  @override
  ConsumerState<HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends ConsumerState<HistorySheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(priceListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // Derive filtered list directly from provider state
    final fullList = state.globalHistory;
    final List<Map<String, dynamic>> filteredHistory;

    if (_searchQuery.isEmpty) {
      filteredHistory = fullList;
    } else {
      final lowerQuery = _searchQuery.toLowerCase();
      filteredHistory = fullList.where((item) {
        final summary = (item['summary'] ?? '').toString().toLowerCase();
        final action = (item['action'] ?? '').toString().toLowerCase();
        final name = (item['emp_name'] ?? '').toString().toLowerCase();
        return summary.contains(lowerQuery) ||
            action.contains(lowerQuery) ||
            name.contains(lowerQuery);
      }).toList();
    }

    debugPrint(
        ' [HistorySheet] build: ${fullList.length} total, ${filteredHistory.length} filtered, isLoading=${state.isLoading}');

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Chip(
                label: Text('Add-Edit-Delete History',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    )),
                backgroundColor: Colors.orange,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search History...',
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.orange),
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkBackground : Colors.grey.shade100,
            ),
            onChanged: (val) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (_searchController.text == val && mounted) {
                  setState(() => _searchQuery = val);
                }
              });
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.primary.withValues(alpha: 0.15) : Colors.orange.shade100,
              border: const Border(bottom: BorderSide(color: Colors.orange)),
            ),
            child: const Row(
              children: [
                _HeaderCell('Action', flex: 2),
                _HeaderCell('Summary', flex: 6),
                _HeaderCell('Name', flex: 2),
                _HeaderCell('Time', flex: 3),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading
                ? _buildSkeletonLoading()
                : filteredHistory.isEmpty
                    ? const Center(
                        child: Text("No records found",
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: filteredHistory.length,
                        itemBuilder: (context, index) {
                          final item = filteredHistory[index];

                          return RepaintBoundary(
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item['action'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                _getActionColor(context, item['action']),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 6,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8.0),
                                          child: Text(
                                            item['summary'] ?? '',
                                            style: TextStyle(
                                                fontSize: 14,
                                                height: 1.3,
                                                color: colorScheme.onSurface),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item['emp_name'] ?? '',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: colorScheme.onSurface),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          item['time_stamp'] ?? '',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: colorScheme.onSurface.withValues(alpha: 0.7)),
                                          textAlign: TextAlign.start,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Divider(height: 1, thickness: 0.5, color: isDark ? AppColors.darkDivider : Colors.grey.shade300),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Color _getActionColor(BuildContext context, String? action) {
    switch (action?.toLowerCase()) {
      case 'created':
        return Colors.green;
      case 'updated':
        return Colors.blue;
      case 'deleted':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  Widget _buildSkeletonLoading() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skeletonColor = isDark ? AppColors.darkBorder : Colors.grey.shade200;
    final skeletonColorAlt = isDark ? AppColors.darkSurfaceAlt : Colors.grey.shade100;
    final dividerColor = isDark ? AppColors.darkDivider : Colors.grey.shade200;

    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: skeletonColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 10,
                    width: 150,
                    decoration: BoxDecoration(
                      color: skeletonColorAlt,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  const _HeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

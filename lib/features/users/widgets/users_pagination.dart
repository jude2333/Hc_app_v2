import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/users_providers.dart';

/// Pagination widget for Users list.
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('Rows per page:', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: pagination.rowsPerPage,
                underline: Container(),
                items: [50, 70, 100, -1].map((value) {
                  return DropdownMenuItem(
                    value: value,
                    child: Text(
                      value == -1 ? 'All' : value.toString(),
                      style: const TextStyle(fontSize: 14),
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
            ],
          ),
          Text(
            pagination.rowsPerPage == -1
                ? '$currentCount users'
                : '$startItem-$endItem of many',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: pagination.page > 1
                    ? () {
                        ref
                            .read(usersPaginationProvider.notifier)
                            .setPage(pagination.page - 1);
                      }
                    : null,
                tooltip: 'Previous page',
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Page ${pagination.page}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: isFullPage
                    ? () {
                        ref
                            .read(usersPaginationProvider.notifier)
                            .setPage(pagination.page + 1);
                      }
                    : null,
                tooltip: 'Next page',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

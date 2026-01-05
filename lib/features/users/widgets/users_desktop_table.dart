import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/user_model.dart';
import '../providers/users_providers.dart';
import 'users_table_row.dart';
import 'users_pagination.dart';

/// Desktop table view for Users page.
class UsersDesktopTable extends ConsumerWidget {
  const UsersDesktopTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersListProvider);

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: usersAsync.when(
              data: (users) {
                if (users.isEmpty) {
                  return const Center(child: Text('No users found'));
                }
                return UsersTableContent(users: users);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          const UsersPagination(),
        ],
      ),
    );
  }
}

/// Table content with header and rows.
class UsersTableContent extends StatelessWidget {
  final List<User> users;

  const UsersTableContent({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                _buildHeaderCell('Name', flex: 3),
                _buildHeaderCell('Mobile', flex: 2),
                _buildHeaderCell('Role', flex: 3),
                _buildHeaderCell('Department', flex: 2),
                _buildHeaderCell('ID Card', flex: 2),
                _buildHeaderCell('Actions', flex: 2, centered: true),
                _buildHeaderCell('', flex: 1, centered: true),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return UserTableRow(user: user, index: index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text,
      {required int flex, bool centered = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87,
          ),
          textAlign: centered ? TextAlign.center : TextAlign.left,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/users_providers.dart';
import 'user_mobile_card.dart';
import 'users_pagination.dart';

/// Mobile list view for Users page.
class UsersMobileList extends ConsumerWidget {
  const UsersMobileList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersListProvider);

    return Column(
      children: [
        Expanded(
          child: usersAsync.when(
            data: (users) {
              if (users.isEmpty) {
                return const Center(child: Text('No users found'));
              }
              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  return UserMobileCard(user: users[index]);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
        const UsersPagination(),
      ],
    );
  }
}

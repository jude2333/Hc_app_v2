import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/features/users/providers/users_providers.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import 'addEditUser.dart';
import '../widgets/users_widgets.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({Key? key}) : super(key: key);

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      ref.read(usersPaginationProvider.notifier).setSearchQuery(value.trim());
    });
  }

  void _addUser() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditUserPage(),
      ),
    ).then((result) {
      if (result == true) {
        ref.refresh(usersListProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              UsersHeader(
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                onAddUser: _addUser,
              ),
              SizedBox(height: AppSpacing.md),
              Expanded(
                child: isMobile
                    ? const UsersMobileList()
                    : const UsersDesktopTable(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

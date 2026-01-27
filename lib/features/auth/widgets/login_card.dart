import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_state.dart';
import '../providers/auth_provider.dart';

class LoginCard extends ConsumerWidget {
  final VoidCallback onGetOtp;
  final VoidCallback onQuickLogin;

  const LoginCard({
    super.key,
    required this.onGetOtp,
    required this.onQuickLogin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final notifier = ref.read(authProvider.notifier);

    return Card(
      elevation: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
            child: const Text(
              'Anderson CRM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextFormField(
                  initialValue: authState.mobile,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    prefixText: '+91 ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  autofocus: true,
                  onChanged: notifier.setMobile,
                  onFieldSubmitted: (_) => onQuickLogin(),
                ),
                if (authState.currentStep == LoginStep.selectRole) ...[
                  const SizedBox(height: 16),
                  RoleSelector(
                    roles: authState.roles,
                    selectedRoleId: authState.selectedRoleId,
                    onRoleSelected: (roleId, roleName) async {
                      await notifier.selectRole(roleId, roleName);
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: authState.rememberMobile,
                      onChanged: (value) {
                        notifier.setRememberMobile(value ?? false);
                      },
                    ),
                    const Expanded(
                      child: Text('Remember my mobile number'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : onGetOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Get OTP'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RoleSelector extends StatelessWidget {
  final List<UserRole> roles;
  final String? selectedRoleId;
  final void Function(String roleId, String roleName) onRoleSelected;

  const RoleSelector({
    super.key,
    required this.roles,
    required this.selectedRoleId,
    required this.onRoleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedRoleId,
      hint: const Text('Select Role'),
      isExpanded: true,
      items: roles.map((role) {
        return DropdownMenuItem<String>(
          value: role.id,
          child: Text(role.name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          final role = roles.firstWhere(
            (r) => r.id == value,
            orElse: () => UserRole(id: value, name: ''),
          );
          onRoleSelected(role.id, role.name);
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Role is required';
        }
        return null;
      },
    );
  }
}

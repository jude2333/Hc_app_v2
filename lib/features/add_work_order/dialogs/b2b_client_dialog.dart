import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/theme/theme.dart';
import '../providers.dart';

class B2BClientDialog extends ConsumerStatefulWidget {
  const B2BClientDialog({super.key});

  @override
  ConsumerState<B2BClientDialog> createState() => _B2BClientDialogState();
}

class _B2BClientDialogState extends ConsumerState<B2BClientDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(b2bClientsProvider);
    final filtered = _searchQuery.isEmpty
        ? clients
        : clients
            .where((c) =>
                c['first_name']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                c['client_master']['client_name']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()))
            .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      child: Container(
        height: 500,
        width: 450,
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(Icons.business, color: AppColors.primary),
                ),
                SizedBox(width: AppSpacing.md),
                Text('Select B2B Client', style: AppTextStyles.h3),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.textHint),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            SizedBox(height: AppSpacing.md),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search clients...',
                prefixIcon: Icon(Icons.search, color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.smAll,
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: AppColors.divider),
                itemBuilder: (context, i) {
                  final client = filtered[i];
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        (client['first_name'] ?? '?')[0].toUpperCase(),
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                    title: Text(
                        '${client['first_name']} ${client['last_name']}',
                        style: AppTextStyles.body),
                    subtitle: Text(
                        client['client_master']?['client_name'] ?? '',
                        style: AppTextStyles.caption),
                    trailing:
                        Icon(Icons.chevron_right, color: AppColors.textHint),
                    onTap: () => Navigator.pop(context, client),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

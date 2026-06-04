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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

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
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surface,
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
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: const Icon(Icons.business, color: AppColors.primary),
                ),
                SizedBox(width: AppSpacing.md),
                Text('Select B2B Client', style: AppTextStyles.h3),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: isDark ? AppColors.darkTextSecondary : AppColors.textHint),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            SizedBox(height: AppSpacing.md),
            TextField(
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search clients...',
                hintStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textHint),
                prefixIcon: Icon(Icons.search, color: isDark ? AppColors.darkTextSecondary : AppColors.textHint),
                filled: true,
                fillColor: isDark ? AppColors.darkBackground : AppColors.surfaceAlt,
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
                    Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.divider),
                itemBuilder: (context, i) {
                  final client = filtered[i];
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        (client['first_name'] ?? '?')[0].toUpperCase(),
                        style: TextStyle(color: isDark ? AppColors.gradientEnd : AppColors.primary),
                      ),
                    ),
                    title: Text(
                        '${client['first_name']} ${client['last_name']}',
                        style: AppTextStyles.body.copyWith(color: colorScheme.onSurface)),
                    subtitle: Text(
                        client['client_master']?['client_name'] ?? '',
                        style: AppTextStyles.caption.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                    trailing:
                        Icon(Icons.chevron_right, color: isDark ? AppColors.darkTextSecondary : AppColors.textHint),
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

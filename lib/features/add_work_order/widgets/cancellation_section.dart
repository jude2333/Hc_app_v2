import 'package:flutter/material.dart';
import '../../../../features/theme/theme.dart';

class CancellationSection extends StatelessWidget {
  final bool isCancelled;
  final TextEditingController reasonController;
  final Function(bool) onToggle;

  const CancellationSection({
    super.key,
    required this.isCancelled,
    required this.reasonController,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.only(top: AppSpacing.lg),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.error.withValues(alpha: 0.15)
            : AppColors.error.withOpacity(0.05),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error),
              SizedBox(width: AppSpacing.sm),
              Text('Cancellation',
                  style: AppTextStyles.h3.copyWith(color: AppColors.error)),
              const Spacer(),
              Switch(
                value: isCancelled,
                activeColor: AppColors.error,
                onChanged: onToggle,
              ),
            ],
          ),
          if (isCancelled) ...[
            SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Reason for Cancellation',
                labelStyle: const TextStyle(color: AppColors.error),
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.smAll,
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.smAll,
                  borderSide:
                      BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.smAll,
                  borderSide: const BorderSide(color: AppColors.error),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ],
      ),
    );
  }
}

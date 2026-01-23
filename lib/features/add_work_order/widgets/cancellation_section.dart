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
    return Container(
      margin: EdgeInsets.only(top: AppSpacing.lg),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.05),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
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
              decoration: InputDecoration(
                labelText: 'Reason for Cancellation',
                labelStyle: TextStyle(color: AppColors.error),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.smAll,
                  borderSide: BorderSide(color: AppColors.error),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.smAll,
                  borderSide:
                      BorderSide(color: AppColors.error.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.smAll,
                  borderSide: BorderSide(color: AppColors.error),
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

import 'package:flutter/material.dart';
import '../../../../features/theme/theme.dart';

/// Shared input decoration for all Add Work Order form fields.
/// Eliminates duplicate `_inputDecoration` methods across section widgets.
class WorkOrderFormStyles {
  WorkOrderFormStyles._();

  static InputDecoration inputDecoration(BuildContext context, String label,
      {IconData? icon, String? prefix}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      ),
      prefixText: prefix,
      prefixStyle: TextStyle(color: colorScheme.onSurface),
      prefixIcon: icon != null
          ? Icon(
              icon,
              size: 20,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
            )
          : null,
      filled: true,
      fillColor: isDark ? AppColors.darkSurface : AppColors.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.divider,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(
          color: AppColors.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: AppColors.error),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
    );
  }
}

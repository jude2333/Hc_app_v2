import 'package:flutter/material.dart';
import '../../../../features/theme/theme.dart';

class SettingsDialog extends StatefulWidget {
  final bool initialSms;
  final bool initialWhatsapp;
  final bool initialEmail;

  const SettingsDialog({
    super.key,
    required this.initialSms,
    required this.initialWhatsapp,
    required this.initialEmail,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late bool _msgSms;
  late bool _msgWhatsapp;
  late bool _msgEmail;

  @override
  void initState() {
    super.initState();
    _msgSms = widget.initialSms;
    _msgWhatsapp = widget.initialWhatsapp;
    _msgEmail = widget.initialEmail;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surface,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.lg),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: const Icon(Icons.notifications_outlined,
                      color: AppColors.primary),
                ),
                SizedBox(width: AppSpacing.md),
                Text('Notification Settings', style: AppTextStyles.h3.copyWith(color: colorScheme.onSurface)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: isDark ? AppColors.darkTextSecondary : AppColors.textHint),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            _buildNotificationToggle(
              context,
              'SMS',
              Icons.sms_outlined,
              _msgSms,
              (v) => setState(() => _msgSms = v),
            ),
            SizedBox(height: AppSpacing.sm),
            _buildNotificationToggle(
              context,
              'WhatsApp',
              Icons.chat_outlined,
              _msgWhatsapp,
              (v) => setState(() => _msgWhatsapp = v),
            ),
            SizedBox(height: AppSpacing.sm),
            _buildNotificationToggle(
              context,
              'Email',
              Icons.email_outlined,
              _msgEmail,
              (v) => setState(() => _msgEmail = v),
            ),
            SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'sms': _msgSms,
                    'whatsapp': _msgWhatsapp,
                    'email': _msgEmail,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
                ),
                child: const Text('Save Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggle(
      BuildContext context, String label, IconData icon, bool value, Function(bool) onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: value
            ? AppColors.success.withValues(alpha: 0.15)
            : (isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt),
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: value
              ? AppColors.success.withValues(alpha: 0.3)
              : (isDark ? AppColors.darkBorder : AppColors.divider),
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: value
                  ? AppColors.success
                  : (isDark ? AppColors.darkTextSecondary : AppColors.textHint),
              size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: value
                        ? AppColors.success
                        : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary))),
          ),
          Switch(
            value: value,
            activeColor: AppColors.success,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

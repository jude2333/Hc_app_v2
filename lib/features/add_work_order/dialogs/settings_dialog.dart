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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
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
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(Icons.notifications_outlined,
                      color: AppColors.primary),
                ),
                SizedBox(width: AppSpacing.md),
                Text('Notification Settings', style: AppTextStyles.h3),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.textHint),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            _buildNotificationToggle(
              'SMS',
              Icons.sms_outlined,
              _msgSms,
              (v) => setState(() => _msgSms = v),
            ),
            SizedBox(height: AppSpacing.sm),
            _buildNotificationToggle(
              'WhatsApp',
              Icons.chat_outlined,
              _msgWhatsapp,
              (v) => setState(() => _msgWhatsapp = v),
            ),
            SizedBox(height: AppSpacing.sm),
            _buildNotificationToggle(
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
                child: Text('Save Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggle(
      String label, IconData icon, bool value, Function(bool) onChanged) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color:
            value ? AppColors.success.withOpacity(0.05) : AppColors.surfaceAlt,
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: value ? AppColors.success.withOpacity(0.3) : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: value ? AppColors.success : AppColors.textHint, size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color:
                        value ? AppColors.success : AppColors.textSecondary)),
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

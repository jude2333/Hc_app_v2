import 'package:flutter/material.dart';
import '../../../../features/theme/theme.dart';

class AppointmentSection extends StatelessWidget {
  final String date;
  final TimeOfDay? time;
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;

  const AppointmentSection({
    super.key,
    required this.date,
    required this.time,
    required this.onDateTap,
    required this.onTimeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: date.isNotEmpty ? date : null,
          decoration: _inputDecoration('Collection Date', icon: Icons.event),
          items: [date] // Ideally this list comes from parent
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: (_) =>
              onDateTap(), // Trigger callback to open date picker instead
        ),
        SizedBox(height: AppSpacing.md),
        InkWell(
          onTap: onTimeTap,
          borderRadius: AppRadius.smAll,
          child: Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              border: Border.all(
                color: time == null ? AppColors.divider : AppColors.divider,
                width: 1,
              ),
              borderRadius: AppRadius.smAll,
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded,
                    color:
                        time == null ? AppColors.textHint : AppColors.primary,
                    size: 20),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    time?.format(context) ?? 'Select Time',
                    style: TextStyle(
                      fontSize: 16,
                      color: time == null
                          ? AppColors.textHint
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (time != null)
                  IconButton(
                    icon:
                        Icon(Icons.clear, size: 18, color: AppColors.textHint),
                    onPressed: () {
                      onTimeTap();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon:
          icon != null ? Icon(icon, size: 20, color: AppColors.textHint) : null,
      filled: true,
      fillColor: AppColors.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
    );
  }
}

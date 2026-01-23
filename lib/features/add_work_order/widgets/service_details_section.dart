import 'package:flutter/material.dart';
import '../../../../features/theme/theme.dart';

class ServiceDetailsSection extends StatelessWidget {
  final TextEditingController doctorController;
  final bool isB2B;
  final String? selectedB2BClient;
  final bool isVip;
  final bool isUrgent;
  final int credit; // 0=None, 1=Credit, 2=Trial
  final Function(bool) onB2BChanged;
  final VoidCallback onSelectB2BClient;
  final Function(bool) onVipChanged;
  final Function(bool) onUrgentChanged;
  final Function(int) onCreditChanged; // Now takes int

  const ServiceDetailsSection({
    super.key,
    required this.doctorController,
    required this.isB2B,
    required this.selectedB2BClient,
    required this.isVip,
    required this.isUrgent,
    required this.credit,
    required this.onB2BChanged,
    required this.onSelectB2BClient,
    required this.onVipChanged,
    required this.onUrgentChanged,
    required this.onCreditChanged,
  });

  @override
  Widget build(BuildContext context) {
    final creditSelect =
        credit == 1 ? 'Credit' : (credit == 2 ? 'Trial' : 'None');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: doctorController,
          textCapitalization: TextCapitalization.words,
          decoration: _inputDecoration('Doctor Name (Optional)',
              icon: Icons.person_outline),
        ),
        SizedBox(height: AppSpacing.lg),
        _buildB2BToggle(),
        SizedBox(height: AppSpacing.lg),
        Text('Tags (Optional)',
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
        SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
                child:
                    _buildTagChip('VIP', isVip, onVipChanged, Colors.purple)),
            SizedBox(width: AppSpacing.sm),
            Expanded(
                child: _buildTagChip(
                    'Urgent', isUrgent, onUrgentChanged, Colors.red)),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        DropdownButtonFormField<String>(
          value: creditSelect,
          decoration: _inputDecoration('Payment Type', icon: Icons.payment),
          items: ['None', 'Credit', 'Trial']
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) {
            final newCredit = v == 'None' ? 0 : (v == 'Credit' ? 1 : 2);
            onCreditChanged(newCredit);
          },
        ),
      ],
    );
  }

  Widget _buildB2BToggle() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.smAll,
        border:
            Border.all(color: isB2B ? AppColors.primary : AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.business,
                  color: isB2B ? AppColors.primary : AppColors.textHint),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('B2B Client',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isB2B
                            ? AppColors.primary
                            : AppColors.textSecondary)),
              ),
              Switch(
                value: isB2B,
                activeColor: AppColors.primary,
                onChanged: onB2BChanged,
              ),
            ],
          ),
          if (isB2B) ...[
            SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: onSelectB2BClient,
              borderRadius: AppRadius.smAll,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.smAll,
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedB2BClient ?? 'Select Client',
                        style: TextStyle(
                          color: selectedB2BClient == null
                              ? AppColors.textHint
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: AppColors.textHint),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
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

  Widget _buildTagChip(
      String label, bool value, Function(bool) onChanged, Color color) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: AppRadius.smAll,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: value ? color.withOpacity(0.1) : AppColors.surfaceAlt,
          borderRadius: AppRadius.smAll,
          border: Border.all(
            color: value ? color : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              value ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: value ? color : AppColors.textHint,
            ),
            SizedBox(width: AppSpacing.xs),
            Text(label,
                style: TextStyle(
                  color: value ? color : AppColors.textSecondary,
                  fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}

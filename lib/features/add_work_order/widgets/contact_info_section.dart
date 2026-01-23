import 'package:flutter/material.dart';
import '../../../../features/theme/theme.dart';

class ContactInfoSection extends StatelessWidget {
  final TextEditingController addressController;
  final TextEditingController pincodeController;
  final TextEditingController freeTextController;
  final VoidCallback onPincodeTap;

  const ContactInfoSection({
    super.key,
    required this.addressController,
    required this.pincodeController,
    required this.freeTextController,
    required this.onPincodeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: addressController,
          maxLines: 2,
          textCapitalization: TextCapitalization.words,
          decoration: _inputDecoration('Address', icon: Icons.home_outlined),
          validator: (v) =>
              v == null || v.isEmpty ? 'Address is required' : null,
        ),
        SizedBox(height: AppSpacing.md),
        InkWell(
          onTap: onPincodeTap,
          borderRadius: AppRadius.smAll,
          child: IgnorePointer(
            child: TextFormField(
              controller: pincodeController,
              decoration: _inputDecoration('Pincode',
                      icon: Icons.pin_drop_outlined)
                  .copyWith(
                      suffixIcon: Icon(Icons.search, color: AppColors.primary)),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Pincode is required' : null,
            ),
          ),
        ),
        SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: freeTextController,
          decoration: _inputDecoration('Landmark / Free Text',
              icon: Icons.note_alt_outlined),
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

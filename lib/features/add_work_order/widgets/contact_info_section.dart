import 'package:flutter/material.dart';
import '../../../../features/theme/theme.dart';
import 'work_order_form_styles.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: addressController,
          maxLines: 2,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: WorkOrderFormStyles.inputDecoration(context, 'Address',
              icon: Icons.home_outlined),
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
              style: TextStyle(color: colorScheme.onSurface),
              decoration: WorkOrderFormStyles.inputDecoration(context, 'Pincode',
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
          style: TextStyle(color: colorScheme.onSurface),
          decoration: WorkOrderFormStyles.inputDecoration(context,
              'Landmark / Free Text',
              icon: Icons.note_alt_outlined),
        ),
      ],
    );
  }
}

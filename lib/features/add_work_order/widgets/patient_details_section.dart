import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../features/theme/theme.dart';
import 'work_order_form_styles.dart';

class PatientDetailsSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController ageController;
  final TextEditingController mobileController;
  final TextEditingController alternateMobileController;
  final TextEditingController emailController;
  final String salutation;
  final String gender;
  final Function(String?) onSalutationChanged;
  final Function(String?) onGenderChanged;

  const PatientDetailsSection({
    super.key,
    required this.nameController,
    required this.ageController,
    required this.mobileController,
    required this.alternateMobileController,
    required this.emailController,
    required this.salutation,
    required this.gender,
    required this.onSalutationChanged,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width <= 800;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (isMobile) ...[
          DropdownButtonFormField<String>(
            dropdownColor: colorScheme.surface,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
            value: salutation.isEmpty ? null : salutation,
            decoration: WorkOrderFormStyles.inputDecoration(context, 'Title'),
            items: ['Mr', 'Ms', 'Mrs', 'Child Of', 'Dr']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: onSalutationChanged,
            validator: (v) => v == null ? 'Required' : null,
          ),
          SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: nameController,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: WorkOrderFormStyles.inputDecoration(
                context, 'Full Name',
                icon: Icons.person_outline),
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  dropdownColor: colorScheme.surface,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                  value: salutation.isEmpty ? null : salutation,
                  decoration:
                      WorkOrderFormStyles.inputDecoration(context, 'Title'),
                  items: ['Mr', 'Ms', 'Mrs', 'Child Of', 'Dr']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: onSalutationChanged,
                  validator: (v) => v == null ? 'Required' : null,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 5,
                child: TextFormField(
                  controller: nameController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: WorkOrderFormStyles.inputDecoration(
                      context, 'Full Name',
                      icon: Icons.person_outline),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: ageController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: WorkOrderFormStyles.inputDecoration(context, 'Age',
                    icon: Icons.cake_outlined),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: DropdownButtonFormField<String>(
                dropdownColor: colorScheme.surface,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                value: gender,
                decoration: WorkOrderFormStyles.inputDecoration(
                    context, 'Gender',
                    icon: Icons.people_outline),
                items: ['Male', 'Female', 'Other']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: onGenderChanged,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: mobileController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(color: colorScheme.onSurface),
          decoration: WorkOrderFormStyles.inputDecoration(
                  context, 'Mobile Number',
                  icon: Icons.phone_android)
              .copyWith(counterText: ""),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Mobile is required';
            if (v.length != 10) return 'Enter valid 10-digit number';
            return null;
          },
        ),
        SizedBox(height: AppSpacing.md),
        SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: alternateMobileController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(color: colorScheme.onSurface),
          decoration: WorkOrderFormStyles.inputDecoration(
                  context, 'Alternate Mobile (Optional)',
                  icon: Icons.phone_callback_outlined)
              .copyWith(counterText: ""),
          validator: (v) {
            if (v != null && v.isNotEmpty && v.length != 10) {
              return 'Enter valid 10-digit number';
            }
            return null;
          },
        ),
      ],
    );
  }
}

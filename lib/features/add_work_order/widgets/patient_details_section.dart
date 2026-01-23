import 'package:flutter/material.dart';
import '../../../../features/theme/theme.dart';

class PatientDetailsSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController ageController;
  final TextEditingController mobileController;
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
    required this.emailController,
    required this.salutation,
    required this.gender,
    required this.onSalutationChanged,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width <= 800;

    return Column(
      children: [
        if (isMobile) ...[
          DropdownButtonFormField<String>(
            value: salutation.isEmpty ? null : salutation,
            decoration: _inputDecoration('Title'),
            items: ['Mr', 'Ms', 'Mrs', 'Child Of', 'Dr']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: onSalutationChanged,
            validator: (v) => v == null ? 'Required' : null,
          ),
          SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: nameController,
            decoration:
                _inputDecoration('Full Name', icon: Icons.person_outline),
            textCapitalization: TextCapitalization.words,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: salutation.isEmpty ? null : salutation,
                  decoration: _inputDecoration('Title'),
                  items: ['Mr', 'Ms', 'Mrs', 'Child Of', 'Dr']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: onSalutationChanged,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 5,
                child: TextFormField(
                  controller: nameController,
                  decoration:
                      _inputDecoration('Full Name', icon: Icons.person_outline),
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
                decoration: _inputDecoration('Age', icon: Icons.cake_outlined),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: gender,
                decoration:
                    _inputDecoration('Gender', icon: Icons.people_outline),
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
          decoration:
              _inputDecoration('Mobile Number', icon: Icons.phone_android)
                  .copyWith(counterText: ""),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Mobile is required';
            if (v.length != 10) return 'Enter valid 10-digit number';
            return null;
          },
        ),
        SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDecoration('Email Address (Optional)',
              icon: Icons.email_outlined),
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

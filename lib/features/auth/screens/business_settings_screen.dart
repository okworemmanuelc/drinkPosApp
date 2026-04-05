import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/features/auth/widgets/onboarding_step_indicator.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';
import 'package:reebaplus_pos/features/auth/screens/create_pin_screen.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:reebaplus_pos/features/auth/widgets/auth_background.dart';
import 'package:reebaplus_pos/core/theme/app_decorations.dart';

class BusinessSettingsScreen extends ConsumerStatefulWidget {
  final UserData user;

  /// Pass true so that the resulting Biometric/PIN screens eventually
  /// show the "Your business is ready" dashboard entry screen.
  final bool isNewBusinessSetup;

  const BusinessSettingsScreen({
    super.key,
    required this.user,
    this.isNewBusinessSetup = true,
  });

  @override
  ConsumerState<BusinessSettingsScreen> createState() =>
      _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState
    extends ConsumerState<BusinessSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _taxController = TextEditingController();

  final List<String> _currencies = [
    'NGN (₦)',
    'USD (\$)',
    'EUR (€)',
    'GBP (£)',
    'GHS (GH₵)',
    'KES (KSh)',
    'ZAR (R)',
  ];
  final List<String> _timezones = [
    'Africa/Lagos',
    'Africa/Accra',
    'Africa/Nairobi',
    'Africa/Johannesburg',
    'Europe/London',
    'America/New_York',
  ];

  String _selectedCurrency = 'NGN (₦)';
  String _selectedTimezone = 'Africa/Lagos';

  bool _loading = false;

  @override
  void dispose() {
    _taxController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final db = ref.read(databaseProvider);
    await db.batch((batch) {
      batch.insert(
        db.appSettings,
        AppSettingsCompanion.insert(
          key: 'default_currency',
          value: _selectedCurrency,
        ),
        mode: InsertMode.insertOrReplace,
      );
      batch.insert(
        db.appSettings,
        AppSettingsCompanion.insert(key: 'timezone', value: _selectedTimezone),
        mode: InsertMode.insertOrReplace,
      );
      if (_taxController.text.trim().isNotEmpty) {
        batch.insert(
          db.appSettings,
          AppSettingsCompanion.insert(
            key: 'tax_registration_number',
            value: _taxController.text.trim(),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });

    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatePinScreen(
          user: widget.user,
          isNewBusinessSetup: widget.isNewBusinessSetup,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return AuthBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: textColor,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const OnboardingStepIndicator(
                    currentStep: 5,
                    totalSteps: 7,
                    stepLabels: OnboardingStepIndicator.pathALabels,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Business Settings',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Configure your core operating settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  _buildDropdownField(
                    label: 'Default Currency',
                    icon: Icons.payments_rounded,
                    value: _selectedCurrency,
                    items: _currencies,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCurrency = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildDropdownField(
                    label: 'Timezone',
                    icon: Icons.access_time_filled_rounded,
                    value: _selectedTimezone,
                    items: _timezones,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedTimezone = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    label: 'Tax Registration Number (Optional)',
                    controller: _taxController,
                    icon: Icons.receipt_long_rounded,
                  ),
                  const SizedBox(height: 48),

                  AppButton(
                    text: 'Continue',
                    isLoading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
        ),
        Container(
          decoration: AppDecorations.glassCard(context),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(
                Icons.arrow_drop_down_rounded,
                color: textColor.withValues(alpha: 0.7),
              ),
              dropdownColor: isDark ? Colors.grey[900] : Colors.white,
              style: TextStyle(color: textColor, fontSize: 16),
              items: items
                  .map(
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(i, style: TextStyle(color: textColor)),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          style: TextStyle(color: textColor),
          decoration: AppDecorations.authInputDecoration(
            context,
            label: '',
            prefixIcon: icon,
          ).copyWith(labelText: null, hintText: 'Enter registration number'),
        ),
      ],
    );
  }
}

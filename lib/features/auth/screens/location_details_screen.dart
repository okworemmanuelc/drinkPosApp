import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/features/auth/widgets/onboarding_step_indicator.dart';
import 'package:reebaplus_pos/features/auth/onboarding/onboarding_draft.dart';
import 'package:reebaplus_pos/features/auth/screens/business_settings_screen.dart';
import 'package:reebaplus_pos/features/auth/widgets/auth_background.dart';
import 'package:reebaplus_pos/core/theme/app_decorations.dart';
import 'package:reebaplus_pos/shared/widgets/smooth_route.dart';

class LocationDetailsScreen extends ConsumerStatefulWidget {
  final String email;
  const LocationDetailsScreen({super.key, required this.email});

  @override
  ConsumerState<LocationDetailsScreen> createState() =>
      _LocationDetailsScreenState();
}

class _LocationDetailsScreenState extends ConsumerState<LocationDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityStateController = TextEditingController();
  final _countryController = TextEditingController();

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingDraftProvider);
    _nameController.text = draft?.locationName ?? '';
    _addressController.text = draft?.streetAddress ?? '';
    _cityStateController.text = draft?.cityState ?? '';
    _countryController.text = draft?.country ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityStateController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    // Write to draft only — atomic commit happens at PIN confirm.
    ref.read(onboardingDraftProvider.notifier).update((d) {
      d.locationName = _nameController.text.trim();
      d.streetAddress = _addressController.text.trim();
      d.cityState = _cityStateController.text.trim();
      d.country = _countryController.text.trim();
    });

    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.of(context).push(
      SmoothRoute(page: BusinessSettingsScreen(email: widget.email)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                    currentStep: 4,
                    totalSteps: 7,
                    stepLabels: OnboardingStepIndicator.pathALabels,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'First Location',
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
                      'Where is your branch located?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildTextField(
                    label: 'Location Name (e.g. Main Branch)',
                    controller: _nameController,
                    icon: Icons.store_rounded,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    label: 'Street Address',
                    controller: _addressController,
                    icon: Icons.map_rounded,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    label: 'City and State',
                    controller: _cityStateController,
                    icon: Icons.location_city_rounded,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    label: 'Country',
                    controller: _countryController,
                    icon: Icons.public_rounded,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 32),

                  // Helper text
                  Center(
                    child: Text(
                      'You can add more locations after setup is complete.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: TextStyle(color: textColor),
      decoration: AppDecorations.authInputDecoration(
        context,
        label: label,
        prefixIcon: icon,
      ),
      validator: validator,
    );
  }
}

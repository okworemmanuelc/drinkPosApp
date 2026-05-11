import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/features/auth/widgets/onboarding_step_indicator.dart';
import 'package:reebaplus_pos/features/auth/onboarding/onboarding_draft.dart';
import 'package:reebaplus_pos/features/auth/screens/location_details_screen.dart';
import 'package:reebaplus_pos/features/auth/widgets/auth_background.dart';
import 'package:reebaplus_pos/core/theme/app_decorations.dart';
import 'package:reebaplus_pos/shared/widgets/smooth_route.dart';

class BusinessDetailsScreen extends ConsumerStatefulWidget {
  final String email;
  const BusinessDetailsScreen({super.key, required this.email});

  @override
  ConsumerState<BusinessDetailsScreen> createState() =>
      _BusinessDetailsScreenState();
}

class _BusinessDetailsScreenState extends ConsumerState<BusinessDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  final List<String> _businessTypes = [
    'Retail',
    'Restaurant',
    'Salon',
    'Pharmacy',
    'Beer Distributor',
    'Supermarket',
    'Wholesale',
    'Other',
  ];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Restore from draft (back navigation, accidental rebuild). Default the
    // business email to the user's login email if nothing in the draft yet.
    final draft = ref.read(onboardingDraftProvider);
    _nameController.text = draft?.businessName ?? '';
    _typeController.text = draft?.businessType ?? '';
    _phoneController.text = draft?.businessPhone ?? '';
    _emailController.text = draft?.businessEmail ?? widget.email;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final businessType = _typeController.text.trim();
    if (businessType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or specify a business type.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    // Write to draft only — atomic commit happens at PIN confirm.
    ref.read(onboardingDraftProvider.notifier).update((d) {
      d.businessName = name;
      d.businessType = businessType;
      d.businessPhone = phone;
      d.businessEmail = email;
    });

    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.of(context).push(
      SmoothRoute(page: LocationDetailsScreen(email: widget.email)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final primary = theme.colorScheme.primary;

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
                    currentStep: 3,
                    totalSteps: 7,
                    stepLabels: OnboardingStepIndicator.pathALabels,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Business Details',
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
                      'Tell us a bit about your company.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Business Logo Upload (Placeholder UI)
                  Center(
                    child: InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Logo upload coming soon.'),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: textColor.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_rounded,
                              color: primary,
                              size: 32,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add Logo\n(Optional)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.5),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildTextField(
                    label: 'Business Name',
                    controller: _nameController,
                    icon: Icons.store_mall_directory_rounded,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildDropdownSearchField(),

                  const SizedBox(height: 16),

                  _buildTextField(
                    label: 'Business Phone',
                    controller: _phoneController,
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    label: 'Business Email',
                    controller: _emailController,
                    icon: Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Invalid Email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

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

  Widget _buildDropdownSearchField() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return DropdownMenu<String>(
      controller: _typeController,
      width: MediaQuery.of(context).size.width - 48,
      dropdownMenuEntries: _businessTypes
          .map(
            (t) => DropdownMenuEntry(
              value: t,
              label: t,
              style: MenuItemButton.styleFrom(foregroundColor: textColor),
            ),
          )
          .toList(),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: textColor.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textColor.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textColor.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
      textStyle: TextStyle(color: textColor),
      hintText: 'Business Type / Category',
      leadingIcon: Icon(
        Icons.category_rounded,
        color: textColor.withValues(alpha: 0.6),
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

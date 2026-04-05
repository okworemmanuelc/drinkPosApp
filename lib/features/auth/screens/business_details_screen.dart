import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/features/auth/widgets/onboarding_step_indicator.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';
import 'package:reebaplus_pos/features/auth/screens/location_details_screen.dart';
import 'package:drift/drift.dart' hide Column;

class BusinessDetailsScreen extends ConsumerStatefulWidget {
  final UserData user;
  const BusinessDetailsScreen({super.key, required this.user});

  @override
  ConsumerState<BusinessDetailsScreen> createState() => _BusinessDetailsScreenState();
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
    _emailController.text = widget.user.email ?? '';
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

    // Save to AppSettings (simulated wait)
    await Future.delayed(const Duration(milliseconds: 400));

    final db = ref.read(databaseProvider);
    await db.batch((batch) {
      batch.insert(
        db.appSettings,
        AppSettingsCompanion.insert(
          key: 'business_name',
          value: _nameController.text.trim(),
        ),
        mode: InsertMode.insertOrReplace,
      );
      batch.insert(
        db.appSettings,
        AppSettingsCompanion.insert(key: 'business_type', value: businessType),
        mode: InsertMode.insertOrReplace,
      );
      batch.insert(
        db.appSettings,
        AppSettingsCompanion.insert(
          key: 'business_phone',
          value: _phoneController.text.trim(),
        ),
        mode: InsertMode.insertOrReplace,
      );
      batch.insert(
        db.appSettings,
        AppSettingsCompanion.insert(
          key: 'business_email',
          value: _emailController.text.trim(),
        ),
        mode: InsertMode.insertOrReplace,
      );
    });

    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LocationDetailsScreen(user: widget.user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/auth_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const OnboardingStepIndicator(
                        currentStep: 3,
                        totalSteps: 7,
                        stepLabels: OnboardingStepIndicator.pathALabels,
                      ),
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'Business Details',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
                            color: Colors.white.withValues(alpha: 0.7),
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
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_rounded,
                                  color: Colors.blueAccent,
                                  size: 32,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Add Logo\n(Optional)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
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
        ],
      ),
    );
  }

  Widget _buildDropdownSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: DropdownMenu<String>(
        controller: _typeController,
        width: MediaQuery.of(context).size.width - 48, // Padding subtracted
        dropdownMenuEntries: _businessTypes
            .map((t) => DropdownMenuEntry(value: t, label: t))
            .toList(),
        inputDecorationTheme: InputDecorationTheme(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        textStyle: const TextStyle(color: Colors.white),
        hintText: 'Business Type / Category',
        leadingIcon: Icon(
          Icons.category_rounded,
          color: Colors.white.withValues(alpha: 0.7),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              prefixIcon: Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: validator,
          ),
        ),
      ),
    );
  }
}

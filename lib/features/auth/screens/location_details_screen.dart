import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/features/auth/widgets/onboarding_step_indicator.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/features/auth/screens/business_settings_screen.dart';
import 'package:drift/drift.dart' as drift;

class LocationDetailsScreen extends StatefulWidget {
  final UserData user;
  const LocationDetailsScreen({super.key, required this.user});

  @override
  State<LocationDetailsScreen> createState() => _LocationDetailsScreenState();
}

class _LocationDetailsScreenState extends State<LocationDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityStateController = TextEditingController();
  final _countryController = TextEditingController();

  bool _loading = false;

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

    final locationCombined =
        '${_addressController.text.trim()}, ${_cityStateController.text.trim()}, ${_countryController.text.trim()}';

    // Save as very first Warehouse / branch
    final warehouseId = await database
        .into(database.warehouses)
        .insert(
          WarehousesCompanion.insert(
            name: _nameController.text.trim(),
            location: drift.Value(locationCombined),
          ),
        );

    // Also update current user to belong to this warehouse
    await (database.update(database.users)
          ..where((u) => u.id.equals(widget.user.id)))
        .write(UsersCompanion(warehouseId: drift.Value(warehouseId)));

    final updatedUser = await database.warehousesDao.getUserById(
      widget.user.id,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            BusinessSettingsScreen(user: updatedUser ?? widget.user),
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
                        currentStep: 4,
                        totalSteps: 7,
                        stepLabels: OnboardingStepIndicator.pathALabels,
                      ),
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'First Location',
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
                          'Where is your branch located?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.7),
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
                            color: Colors.white.withValues(alpha: 0.5),
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
        ],
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

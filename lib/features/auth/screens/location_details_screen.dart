import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/features/auth/widgets/onboarding_step_indicator.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';
import 'package:reebaplus_pos/features/auth/screens/business_settings_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'package:reebaplus_pos/features/auth/widgets/auth_background.dart';
import 'package:reebaplus_pos/core/theme/app_decorations.dart';

class LocationDetailsScreen extends ConsumerStatefulWidget {
  final UserData user;
  const LocationDetailsScreen({super.key, required this.user});

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

  /// Set after the first successful submit so a second press updates
  /// the existing warehouse instead of creating a duplicate.
  int? _savedWarehouseId;

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

    final db = ref.read(databaseProvider);
    final int warehouseId;

    if (_savedWarehouseId != null) {
      // User went back and re-submitted — update the existing warehouse.
      warehouseId = _savedWarehouseId!;
      await (db.update(
        db.warehouses,
      )..where((w) => w.id.equals(warehouseId))).write(
        WarehousesCompanion(
          name: drift.Value(_nameController.text.trim()),
          location: drift.Value(locationCombined),
        ),
      );
    } else {
      // First submission — insert a new warehouse.
      warehouseId = await db
          .into(db.warehouses)
          .insert(
            WarehousesCompanion.insert(
              name: _nameController.text.trim(),
              location: drift.Value(locationCombined),
            ),
          );
      _savedWarehouseId = warehouseId;
    }

    // Keep current user assigned to this warehouse.
    await (db.update(db.users)..where((u) => u.id.equals(widget.user.id)))
        .write(UsersCompanion(warehouseId: drift.Value(warehouseId)));

    final updatedUser = await db.warehousesDao.getUserById(widget.user.id);

    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            BusinessSettingsScreen(user: updatedUser ?? widget.user),
      ),
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

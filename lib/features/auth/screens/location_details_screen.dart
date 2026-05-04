import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/features/auth/widgets/onboarding_step_indicator.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/database/uuid_v7.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';
import 'package:reebaplus_pos/features/auth/screens/business_settings_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'package:reebaplus_pos/features/auth/widgets/auth_background.dart';
import 'package:reebaplus_pos/core/theme/app_decorations.dart';
import 'package:reebaplus_pos/shared/widgets/smooth_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  String? _savedWarehouseId;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  /// Pre-fills the form from Supabase. On a resume after interruption,
  /// the warehouse row from the previous attempt rehydrates the inputs.
  Future<void> _loadExistingData() async {
    try {
      final row = await Supabase.instance.client
          .from('warehouses')
          .select()
          .eq('business_id', widget.user.businessId)
          .limit(1)
          .maybeSingle();
      if (row == null || !mounted) return;
      final location = (row['location'] as String?) ?? '';
      final parts = location.split(', ');
      setState(() {
        _savedWarehouseId = row['id'] as String?;
        _nameController.text = (row['name'] as String?) ?? '';
        if (parts.isNotEmpty) _addressController.text = parts[0];
        if (parts.length >= 2) _cityStateController.text = parts[1];
        if (parts.length >= 3) _countryController.text = parts[2];
      });
    } catch (e) {
      debugPrint('[LocationDetailsScreen] _loadExistingData failed: $e');
    }
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

    final locationCombined =
        '${_addressController.text.trim()}, ${_cityStateController.text.trim()}, ${_countryController.text.trim()}';

    final db = ref.read(databaseProvider);
    final String warehouseId;
    final now = DateTime.now();

    if (_savedWarehouseId != null) {
      warehouseId = _savedWarehouseId!;
      await (db.update(
        db.warehouses,
      )..where((w) => w.id.equals(warehouseId))).write(
        WarehousesCompanion(
          businessId: drift.Value(widget.user.businessId),
          name: drift.Value(_nameController.text.trim()),
          location: drift.Value(locationCombined),
          lastUpdatedAt: drift.Value(now),
        ),
      );
    } else {
      warehouseId = UuidV7.generate();
      await db.into(db.warehouses).insert(
            WarehousesCompanion.insert(
              id: drift.Value(warehouseId),
              businessId: widget.user.businessId,
              name: _nameController.text.trim(),
              location: drift.Value(locationCombined),
              lastUpdatedAt: drift.Value(now),
            ),
          );
      _savedWarehouseId = warehouseId;
    }

    // Push the warehouse to Supabase directly. Onboarding is online-first;
    // the sync queue would call requireBusinessId() against a null
    // AuthService.value (intentional — see _onAuthChanged in main.dart).
    // Profile was inserted in BusinessDetailsScreen, so public.business_id()
    // resolves and the standard tenant_insert/update RLS policies accept this.
    // Upsert handles both first submit and re-submit (when the user goes back).
    await Supabase.instance.client.from('warehouses').upsert({
      'id': warehouseId,
      'business_id': widget.user.businessId,
      'name': _nameController.text.trim(),
      'location': locationCombined,
      'last_updated_at': now.toIso8601String(),
      'is_deleted': false,
    });

    // Keep current user assigned to this warehouse.
    await (db.update(db.users)..where((u) => u.id.equals(widget.user.id)))
        .write(UsersCompanion(warehouseId: drift.Value(warehouseId)));

    final updatedUser = await db.warehousesDao.getUserById(widget.user.id);

    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.of(context).push(
      SmoothRoute(
        page: BusinessSettingsScreen(user: updatedUser ?? widget.user),
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

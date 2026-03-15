import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/services/auth_service.dart';
import '../../../core/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'warehouse_setup_screen.dart';

class BusinessSetupScreen extends StatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends State<BusinessSetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  int _currentStep = 0; // 0 = Business Info, 1 = CEO Profile

  // Business fields
  final _businessNameController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _businessAddressController = TextEditingController();

  // CEO fields (pre-filled from auth)
  final _ceoNameController = TextEditingController();
  final _ceoEmailController = TextEditingController();
  final _ceoPhoneController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();

    // Pre-fill CEO details from current user
    final user = authService.currentUser;
    if (user != null) {
      _ceoNameController.text = user.name;
      _ceoEmailController.text = user.email ?? '';
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessPhoneController.dispose();
    _businessEmailController.dispose();
    _businessAddressController.dispose();
    _ceoNameController.dispose();
    _ceoEmailController.dispose();
    _ceoPhoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _animController.reset();
    _animController.forward();
  }

  Future<void> _handleNext() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentStep == 0) {
      _goToStep(1);
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Save business info to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('business_name', _businessNameController.text.trim());
      await prefs.setString('business_phone', _businessPhoneController.text.trim());
      await prefs.setString('business_email', _businessEmailController.text.trim());
      await prefs.setString('business_address', _businessAddressController.text.trim());

      // Promote current user to CEO (roleTier 5)
      final user = authService.currentUser;
      if (user != null) {
        await (database.update(database.users)
              ..where((t) => t.id.equals(user.id)))
            .write(UsersCompanion(
          name: Value(_ceoNameController.text.trim().isNotEmpty
              ? _ceoNameController.text.trim()
              : user.name),
          role: const Value('owner'),
          roleTier: const Value(5),
        ));

        // Reload user in auth service
        final updated = await (database.select(database.users)
              ..where((t) => t.id.equals(user.id)))
            .getSingleOrNull();
        if (updated != null) authService.value = updated;
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const WarehouseSetupScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving business: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenHeight < 700;
    final maxFormWidth = screenWidth.clamp(0.0, 480.0);

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/auth_gradient_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.45)),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top handle + back button
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      if (_currentStep > 0)
                        IconButton(
                          onPressed: () => _goToStep(0),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white70, size: 20),
                        )
                      else
                        const SizedBox(width: 48),
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.spacingL,
                        vertical: context.spacingM,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxFormWidth),
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: SlideTransition(
                            position: _slideAnim,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Step indicator
                                _buildStepIndicator(),
                                SizedBox(height: isSmall ? 16 : 24),

                                // Header
                                _buildHeader(isSmall),
                                SizedBox(height: isSmall ? 20 : 28),

                                // Form Card
                                GlassCard(
                                  padding: EdgeInsets.all(context.spacingL),
                                  borderRadius: BorderRadius.circular(24),
                                  opacity: 0.12,
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (_currentStep == 0)
                                          ..._buildBusinessFields()
                                        else
                                          ..._buildCeoFields(),

                                        const SizedBox(height: 24),

                                        // Action button
                                        SizedBox(
                                          width: double.infinity,
                                          height: 52,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF2563EB),
                                                  Color(0xFF7C3AED),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF2563EB)
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton(
                                              onPressed: _isLoading
                                                  ? null
                                                  : _handleNext,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                              ),
                                              child: _isLoading
                                                  ? const SizedBox(
                                                      width: 22,
                                                      height: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  : Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          _currentStep == 0
                                                              ? 'Next'
                                                              : 'Finish Setup',
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Icon(
                                                          _currentStep == 0
                                                              ? Icons
                                                                  .arrow_forward_rounded
                                                              : Icons
                                                                  .check_rounded,
                                                          color: Colors.white,
                                                          size: 18,
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),
                                Text(
                                  'You can update these details anytime in Settings.',
                                  textAlign: TextAlign.center,
                                  style: context.bodySmall.copyWith(
                                    color: Colors.white38,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final isActive = index == _currentStep;
        final isDone = index < _currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: isDone
                ? AppColors.success
                : isActive
                    ? const Color(0xFF60A5FA)
                    : Colors.white.withValues(alpha: 0.2),
          ),
          child: isDone
              ? const Icon(Icons.check, color: Colors.white, size: 8)
              : null,
        );
      }),
    );
  }

  Widget _buildHeader(bool isSmall) {
    final titles = ['Set Up Your Business', 'CEO Account'];
    final subtitles = [
      'Register your business to get started',
      'Confirm the account for the business owner',
    ];
    final icons = [Icons.store_rounded, Icons.badge_rounded];

    return Column(
      children: [
        Container(
          width: isSmall ? 52 : 64,
          height: isSmall ? 52 : 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: const Color(0xFF60A5FA).withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Icon(
            icons[_currentStep],
            color: const Color(0xFF60A5FA),
            size: isSmall ? 26 : 32,
          ),
        ),
        SizedBox(height: isSmall ? 10 : 14),
        Text(
          titles[_currentStep],
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: isSmall ? 22 : 26,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitles[_currentStep],
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white60,
            fontSize: isSmall ? 13 : 14,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBusinessFields() {
    return [
      _sectionLabel('Business Details'),
      const SizedBox(height: 14),
      _buildTextField(
        controller: _businessNameController,
        label: 'Business Name',
        icon: Icons.store_outlined,
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Business name is required' : null,
      ),
      const SizedBox(height: 14),
      _buildTextField(
        controller: _businessPhoneController,
        label: 'Business Phone',
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Phone number is required' : null,
      ),
      const SizedBox(height: 14),
      _buildTextField(
        controller: _businessEmailController,
        label: 'Business Email (optional)',
        icon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 14),
      _buildTextField(
        controller: _businessAddressController,
        label: 'Business Address (optional)',
        icon: Icons.location_on_outlined,
        maxLines: 2,
      ),
    ];
  }

  List<Widget> _buildCeoFields() {
    return [
      _sectionLabel('CEO / Owner Profile'),
      const SizedBox(height: 6),
      _infoChip(
          'This account will have full access to all features and settings.'),
      const SizedBox(height: 14),
      _buildTextField(
        controller: _ceoNameController,
        label: 'Full Name',
        icon: Icons.person_outline_rounded,
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Name is required' : null,
      ),
      const SizedBox(height: 14),
      _buildTextField(
        controller: _ceoEmailController,
        label: 'Email Address',
        icon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
        readOnly: true,
      ),
      const SizedBox(height: 14),
      _buildTextField(
        controller: _ceoPhoneController,
        label: 'Phone Number',
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Phone number is required' : null,
      ),
      const SizedBox(height: 14),
      // Role badge
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Colors.white54, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Role',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Owner / CEO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                ),
              ),
              child: const Text(
                'Full Access',
                style: TextStyle(
                  color: Color(0xFFC4B5FD),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF60A5FA),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _infoChip(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFF60A5FA), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(
        color: readOnly
            ? Colors.white.withValues(alpha: 0.5)
            : Colors.white,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        filled: true,
        fillColor: readOnly
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 14 : 16,
        ),
      ),
    );
  }
}


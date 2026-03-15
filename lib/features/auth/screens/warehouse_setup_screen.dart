import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'pin_setup_screen.dart';

class WarehouseSetupScreen extends StatefulWidget {
  const WarehouseSetupScreen({super.key});

  @override
  State<WarehouseSetupScreen> createState() => _WarehouseSetupScreenState();
}

class _WarehouseSetupScreenState extends State<WarehouseSetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Each entry: {name, location}
  final List<_WarehouseEntry> _entries = [_WarehouseEntry()];

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
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    _animController.dispose();
    super.dispose();
  }

  void _addEntry() {
    setState(() => _entries.add(_WarehouseEntry()));
    // Slight delay so the new field animates in
    Future.delayed(const Duration(milliseconds: 50), () {
      _animController.reset();
      _animController.forward();
    });
  }

  void _removeEntry(int index) {
    _entries[index].dispose();
    setState(() => _entries.removeAt(index));
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      for (final entry in _entries) {
        final name = entry.nameController.text.trim();
        final location = entry.locationController.text.trim();
        if (name.isEmpty) continue;
        await database.into(database.warehouses).insert(
              WarehousesCompanion.insert(
                name: name,
                location: location.isEmpty ? const Value.absent() : Value(location),
              ),
            );
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const PinSetupScreen(),
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
          content: Text('Error saving warehouse: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<void> _skipSetup() async {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const PinSetupScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
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
                // Top row: progress hint
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      // Step chips
                      const _StepChip(label: 'Business', done: true),
                      const SizedBox(width: 6),
                      const _StepChip(label: 'Warehouse', active: true),
                      const SizedBox(width: 6),
                      const _StepChip(label: 'PIN'),
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
                                // Header
                                _buildHeader(isSmall),
                                SizedBox(height: isSmall ? 20 : 28),

                                // Form
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ..._entries.asMap().entries.map((e) =>
                                          _buildWarehouseCard(
                                              e.key, e.value, isSmall)),

                                      // Add another button
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: _addEntry,
                                          icon: const Icon(
                                            Icons.add_rounded,
                                            color: Color(0xFF60A5FA),
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Add Another Warehouse',
                                            style: TextStyle(
                                              color: Color(0xFF60A5FA),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            side: BorderSide(
                                              color: const Color(0xFF60A5FA)
                                                  .withValues(alpha: 0.4),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                        ),
                                      ),

                                      SizedBox(height: isSmall ? 20 : 28),

                                      // Submit button
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
                                            onPressed:
                                                _isLoading ? null : _handleSubmit,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
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
                                                : const Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        'Save & Continue',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Icon(
                                                        Icons.arrow_forward_rounded,
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

                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _isLoading ? null : _skipSetup,
                                  child: const Text(
                                    'Skip for now',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 14,
                                    ),
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

  Widget _buildHeader(bool isSmall) {
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
            Icons.warehouse_rounded,
            color: const Color(0xFF60A5FA),
            size: isSmall ? 26 : 32,
          ),
        ),
        SizedBox(height: isSmall ? 10 : 14),
        Text(
          'Create a Warehouse',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: isSmall ? 22 : 26,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Add at least one warehouse to track your\ninventory and stock levels.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white60,
            fontSize: isSmall ? 13 : 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildWarehouseCard(int index, _WarehouseEntry entry, bool isSmall) {
    final canRemove = _entries.length > 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: EdgeInsets.all(isSmall ? 16 : 20),
        borderRadius: BorderRadius.circular(20),
        opacity: 0.12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Card header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Warehouse ${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF60A5FA),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (canRemove)
                  GestureDetector(
                    onTap: () => _removeEntry(index),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.redAccent,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Warehouse name
            _buildTextField(
              controller: entry.nameController,
              label: 'Warehouse Name',
              icon: Icons.warehouse_outlined,
              hint: 'e.g. Main Store, Annex B',
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Warehouse name is required'
                  : null,
            ),
            const SizedBox(height: 12),

            // Location
            _buildTextField(
              controller: entry.locationController,
              label: 'Location / Address (optional)',
              icon: Icons.location_on_outlined,
              hint: 'e.g. 14 Market Road, Lagos',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

// ─── Step progress chip ────────────────────────────────────────────────────
class _StepChip extends StatelessWidget {
  final String label;
  final bool done;
  final bool active;

  const _StepChip({
    required this.label,
    this.done = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color textColor;
    if (done) {
      bg = AppColors.success.withValues(alpha: 0.2);
      textColor = AppColors.success;
    } else if (active) {
      bg = const Color(0xFF2563EB).withValues(alpha: 0.25);
      textColor = const Color(0xFF60A5FA);
    } else {
      bg = Colors.white.withValues(alpha: 0.08);
      textColor = Colors.white38;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: done
              ? AppColors.success.withValues(alpha: 0.4)
              : active
                  ? const Color(0xFF60A5FA).withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done) ...[
            const Icon(Icons.check_rounded, color: AppColors.success, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helper class for warehouse form entries ───────────────────────────────
class _WarehouseEntry {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  void dispose() {
    nameController.dispose();
    locationController.dispose();
  }
}

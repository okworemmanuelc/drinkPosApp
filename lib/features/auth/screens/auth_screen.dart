import 'package:flutter/material.dart';
import 'package:ribaplus_pos/core/theme/design_tokens.dart';
import 'package:ribaplus_pos/shared/widgets/main_layout.dart';
import 'package:ribaplus_pos/core/database/app_database.dart';
import 'package:ribaplus_pos/features/auth/widgets/staff_selector.dart';
import 'package:ribaplus_pos/features/auth/widgets/pin_pad_view.dart';
import 'package:ribaplus_pos/shared/widgets/security_wrapper.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  UserData? _selectedStaff;
  List<UserData> _staffList = [];
  bool _isLoading = true;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    final staff = await database.select(database.users).get();
    if (mounted) {
      setState(() {
        _staffList = staff;
        _isLoading = false;
      });
      _controller.forward();
    }
  }

  void _selectStaff(UserData staff) {
    setState(() {
      _selectedStaff = staff;
    });
    _controller.reset();
    _controller.forward();
  }

  void _onBack() {
    setState(() {
      _selectedStaff = null;
    });
    _controller.reset();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive spacers — proportional to screen height, clamped for safety
    final topSpace = (screenHeight * 0.045).clamp(24.0, 56.0);
    final logoTextGap = (screenHeight * 0.012).clamp(8.0, 20.0);
    final textSubtextGap = (screenHeight * 0.008).clamp(4.0, 12.0);
    final headerContentGap = (screenHeight * 0.04).clamp(24.0, 56.0);

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
            child: Container(
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                SizedBox(height: topSpace),
                // Header — logo with Hero animation
                Hero(
                  tag: 'auth_logo',
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF2563EB).withValues(alpha: 0.5),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/ribaplus_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: logoTextGap),
                Text(
                  _selectedStaff == null ? 'Staff Entrance' : 'Security Check',
                  style: context.h2.copyWith(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: textSubtextGap),
                Text(
                  _selectedStaff == null
                      ? 'Select your profile to continue'
                      : 'Verification required',
                  style:
                      context.bodyMedium.copyWith(color: Colors.white70),
                ),
                SizedBox(height: headerContentGap),

                // Main Content
                Expanded(
                  child: FadeTransition(
                    opacity: _animation,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.spacingL),
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white))
                          : _selectedStaff == null
                              ? SingleChildScrollView(
                                  child: StaffSelector(
                                    staffList: _staffList,
                                    onStaffSelected: _selectStaff,
                                  ),
                                )
                              : PinPadView(
                                  staff: _selectedStaff!,
                                  onBack: _onBack,
                                  onSuccess: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SecurityWrapper(
                                          child: MainLayout(),
                                        ),
                                      ),
                                    );
                                  },
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
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/services/auth_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/widgets/main_layout.dart';
import '../../../shared/widgets/security_wrapper.dart';
import 'login_screen.dart';

/// Quick Access screen for returning users — PIN entry + biometric option.
class QuickAccessScreen extends StatefulWidget {
  const QuickAccessScreen({super.key});

  @override
  State<QuickAccessScreen> createState() => _QuickAccessScreenState();
}

class _QuickAccessScreenState extends State<QuickAccessScreen>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  int _failures = 0;
  int _cooldownSeconds = 0;
  Timer? _timer;
  bool _isShaking = false;
  UserData? _user;
  bool _biometricAvailable = false;

  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await authService.getQuickAccessUser();
    if (user == null) {
      _goToLogin();
      return;
    }

    bool biometric = false;
    if (user.biometricEnabled) {
      biometric = await biometricService.isAvailable;
    }

    if (mounted) {
      setState(() {
        _user = user;
        _biometricAvailable = biometric;
      });

      // Auto-prompt biometric
      if (biometric) {
        _authenticateWithBiometric();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _cooldownSeconds = 30;
      _failures = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  void _onDigitPress(String digit) {
    if (_cooldownSeconds > 0 || _enteredPin.length >= 4) return;
    setState(() => _enteredPin += digit);

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(
          () => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
    }
  }

  Future<void> _verifyPin() async {
    if (_user == null) return;

    if (_enteredPin == _user!.pin) {
      // Show signing-in dialog immediately to eliminate the visible lag.
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _SigningInDialog(),
      );
      await authService.loginWithPin(_enteredPin);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // close dialog
        _navigateToHome();
      }
    } else {
      _handleFailure();
    }
  }

  Future<void> _authenticateWithBiometric() async {
    final success =
        await biometricService.authenticate(reason: 'Unlock Ribaplus POS');
    if (success && _user != null) {
      await authService.loginWithPin(_user!.pin);
      _navigateToHome();
    }
  }

  void _handleFailure() {
    setState(() {
      _failures++;
      _isShaking = true;
    });

    _shakeController
        .forward(from: 0)
        .then((_) => setState(() => _isShaking = false));

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _enteredPin = '');
        if (_failures >= 3) {
          _startCooldown();
        }
      }
    });
  }

  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const SecurityWrapper(child: MainLayout()),
      ),
      (_) => false,
    );
  }

  void _goToLogin() {
    authService.disableQuickAccess();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmall = screenHeight < 700;

    if (_user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Parse avatar color
    Color avatarColor;
    try {
      avatarColor = Color(
          int.parse(_user!.avatarColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      avatarColor = AppColors.primary;
    }

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
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),

          SafeArea(
            child: Column(
              children: [
                SizedBox(height: isSmall ? 28 : 48),

                // Avatar
                Container(
                  width: isSmall ? 60 : 72,
                  height: isSmall ? 60 : 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: avatarColor.withValues(alpha: 0.2),
                    border: Border.all(
                      color: avatarColor.withValues(alpha: 0.6),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: avatarColor.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _user!.name.isNotEmpty
                          ? _user!.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: avatarColor,
                        fontSize: isSmall ? 24 : 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: isSmall ? 10 : 16),

                Text(
                  'Welcome back',
                  style: context.bodyMedium
                      .copyWith(color: Colors.white60),
                ),
                const SizedBox(height: 4),
                Text(
                  _user!.name,
                  style: context.h2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: isSmall ? 22 : 26,
                  ),
                ),

                SizedBox(height: isSmall ? 20 : 32),

                // PIN dots
                _buildPinDots(),

                if (_cooldownSeconds > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Too many attempts. Wait $_cooldownSeconds s',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else if (_failures > 0 && _enteredPin.isEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Incorrect PIN',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],

                SizedBox(height: isSmall ? 16 : 28),

                // Num pad
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        _buildRow(['1', '2', '3']),
                        _buildRow(['4', '5', '6']),
                        _buildRow(['7', '8', '9']),
                        _buildRow([
                          _biometricAvailable ? 'biometric' : null,
                          '0',
                          'delete',
                        ]),
                      ],
                    ),
                  ),
                ),

                // Switch account
                TextButton(
                  onPressed: _goToLogin,
                  child: const Text(
                    'Use a different account',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                  ),
                ),
                SizedBox(height: isSmall ? 8 : 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinDots() {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final double offset = _isShaking
            ? (0.5 - (0.5 - _shakeController.value).abs()) * 20
            : 0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < _enteredPin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: isFilled
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                  boxShadow: isFilled
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildRow(List<String?> items) {
    return Expanded(
      child: Row(
        children: items.map((item) {
          if (item == null) return const Expanded(child: SizedBox());
          if (item == 'delete') {
            return _buildKey(
              child: const Icon(Icons.backspace_outlined,
                  color: Colors.white70, size: 22),
              onTap: _onDelete,
            );
          }
          if (item == 'biometric') {
            return _buildKey(
              child: const Icon(Icons.fingerprint,
                  color: Colors.white70, size: 28),
              onTap: _authenticateWithBiometric,
            );
          }
          return _buildKey(
            child: Text(
              item,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w300,
              ),
            ),
            onTap: () => _onDigitPress(item),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKey({required Widget child, required VoidCallback onTap}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Material(
          color: Colors.white.withValues(alpha: 0.05),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _cooldownSeconds > 0 ? null : onTap,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _SigningInDialog extends StatelessWidget {
  const _SigningInDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            SizedBox(height: 18),
            Text(
              'Signing in…',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/services/auth_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../shared/widgets/main_layout.dart';
import '../../../shared/widgets/security_wrapper.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _biometricsAvailable = false;
  bool _enableBiometric = false;
  String? _error;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await biometricService.isAvailable;
    if (mounted) {
      setState(() => _biometricsAvailable = available);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onDigitPress(String digit) {
    setState(() => _error = null);

    if (!_isConfirming) {
      if (_pin.length < 4) {
        setState(() => _pin += digit);
        if (_pin.length == 4) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() => _isConfirming = true);
              _animController.reset();
              _animController.forward();
            }
          });
        }
      }
    } else {
      if (_confirmPin.length < 4) {
        setState(() => _confirmPin += digit);
        if (_confirmPin.length == 4) {
          _verifyPin();
        }
      }
    }
  }

  void _onDelete() {
    if (!_isConfirming) {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
    } else {
      if (_confirmPin.isNotEmpty) {
        setState(
          () => _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1),
        );
      }
    }
  }

  Future<void> _verifyPin() async {
    if (_pin != _confirmPin) {
      setState(() {
        _error = 'PINs do not match. Try again.';
        _confirmPin = '';
        _isConfirming = false;
        _pin = '';
      });
      _animController.reset();
      _animController.forward();
      return;
    }

    await authService.setPin(_pin);
    if (_enableBiometric) {
      await authService.setBiometric(true);
    }
    await authService.enableQuickAccess();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const SecurityWrapper(child: MainLayout()),
        ),
        (_) => false,
      );
    }
  }

  void _skipSetup() async {
    await authService.enableQuickAccess();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const SecurityWrapper(child: MainLayout()),
        ),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmall = screenHeight < 700;

    final currentPin = _isConfirming ? _confirmPin : _pin;

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
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  SizedBox(height: isSmall ? 24 : 40),

                  // Header
                  Icon(
                    Icons.security_rounded,
                    color: const Color(0xFF60A5FA),
                    size: isSmall ? 48 : 64,
                  ),
                  SizedBox(height: isSmall ? 12 : 20),
                  Text(
                    _isConfirming ? 'Confirm PIN' : 'Set Up Quick Access',
                    style: context.h2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: isSmall ? 22 : 26,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _isConfirming
                          ? 'Re-enter your 4-digit PIN to confirm'
                          : 'Create a 4-digit PIN for quick sign-in',
                      textAlign: TextAlign.center,
                      style: context.bodyMedium.copyWith(color: Colors.white60),
                    ),
                  ),

                  SizedBox(height: isSmall ? 24 : 36),

                  // PIN dots
                  _buildPinDots(currentPin),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],

                  // Biometric toggle (only when setting initial PIN)
                  if (!_isConfirming && _biometricsAvailable) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        opacity: 0.08,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.fingerprint,
                              color: Colors.white70,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Enable Fingerprint',
                                style: context.bodyMedium.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Switch(
                              value: _enableBiometric,
                              onChanged: (v) =>
                                  setState(() => _enableBiometric = v),
                              activeThumbColor: const Color(0xFF60A5FA),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: isSmall ? 16 : 28),

                  // Num Pad
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        children: [
                          _buildRow(['1', '2', '3']),
                          _buildRow(['4', '5', '6']),
                          _buildRow(['7', '8', '9']),
                          _buildRow([null, '0', 'delete']),
                        ],
                      ),
                    ),
                  ),

                  // Skip button
                  TextButton(
                    onPressed: _skipSetup,
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  ),
                  SizedBox(height: isSmall ? 8 : 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinDots(String pin) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < pin.length;
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
    );
  }

  Widget _buildRow(List<String?> items) {
    return Expanded(
      child: Row(
        children: items.map((item) {
          if (item == null) return const Expanded(child: SizedBox());
          if (item == 'delete') {
            return _buildKey(
              child: const Icon(
                Icons.backspace_outlined,
                color: Colors.white70,
                size: 22,
              ),
              onTap: _onDelete,
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
            onTap: onTap,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}


import 'dart:ui';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/features/auth/screens/biometric_setup_screen.dart';

/// Shown to new staff (pin == '') after their email OTP is verified.
/// Two-phase flow: enter PIN → confirm PIN → save to DB → auto-login.
class CreatePinScreen extends StatefulWidget {
  final UserData user;
  final bool isNewBusinessSetup;
  final bool isJoinFlow;

  const CreatePinScreen({
    super.key,
    required this.user,
    this.isNewBusinessSetup = false,
    this.isJoinFlow = false,
  });

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  final GlobalKey<_ShakeWidgetState> _shakeKey = GlobalKey();
  String _pin = '';
  String _firstPin = '';
  String? _errorMessage;
  bool _confirming = false; // false = create phase, true = confirm phase
  bool _saving = false;

  static const _blockedPins = {
    '000000',
    '111111',
    '123456',
    '654321',
    '222222',
    '333333',
  };

  void _onDigit(String digit) {
    if (_pin.length >= 6 || _saving) return;
    setState(() {
      _pin += digit;
      _errorMessage = null;
    });
    if (_pin.length == 6) _advance();
  }

  void _onBackspace() {
    if (_pin.isEmpty || _saving) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _advance() async {
    if (!_confirming) {
      if (_blockedPins.contains(_pin)) {
        setState(() {
          _errorMessage = "Please choose a stronger PIN.";
          _pin = '';
        });
        _shakeKey.currentState?.shake();
        return;
      }

      // Move to confirmation phase
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _confirming = true;
      });
      return;
    }

    // Confirm phase — check match
    if (_pin != _firstPin) {
      setState(() {
        _pin = '';
        _firstPin = '';
        _confirming = false;
        _errorMessage = "PINs don't match. Try again.";
      });
      _shakeKey.currentState?.shake();
      return;
    }

    // PINs match — save to DB then log in
    setState(() => _saving = true);
    try {
      await (database.update(database.users)
            ..where((u) => u.id.equals(widget.user.id)))
          .write(UsersCompanion(pin: Value(_pin)));

      final updatedUser = await database.warehousesDao.getUserById(
        widget.user.id,
      );

      if (!mounted) return;

      if (updatedUser == null) {
        setState(() {
          _saving = false;
          _errorMessage = 'Unexpected error. Please try again.';
        });
        return;
      }

      // Controlled delay (1.2s) to let the user feel the success
      // before transitioning to the main dashboard.
      await Future.delayed(const Duration(milliseconds: 1200));

      // Transition to biometric setup screen, passing updatedUser
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BiometricSetupScreen(
              user: widget.user,
              isNewBusinessSetup: widget.isNewBusinessSetup,
              isJoinFlow: widget.isJoinFlow,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = 'Failed to save PIN. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/auth_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
            ),
          ),
          // Blur overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Image.asset(
                      'assets/images/reebaplus_logo.png',
                      height: 80,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.storefront,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      _confirming ? 'Confirm your PIN' : 'Create a PIN',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Welcome, ${widget.user.name}!',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _confirming
                          ? 'Re-enter the same PIN to confirm'
                          : 'Choose a 6-digit PIN for quick login',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (!_confirming) ...[
                      const SizedBox(height: 4),
                      Text(
                        'You\'ll use this PIN every time you log in',
                        style: TextStyle(
                          fontSize: 12,
                          color: _errorMessage != null
                              ? Colors.transparent
                              : Colors.white.withValues(alpha: 0.4),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 36),

                    // Six dots
                    _ShakeWidget(
                      key: _shakeKey,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (i) {
                          final filled = i < _pin.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled
                                  ? primary
                                  : Colors.white.withValues(alpha: 0.1),
                              border: Border.all(
                                color: filled
                                    ? primary
                                    : Colors.white.withValues(alpha: 0.4),
                                width: 2,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Error / saving feedback
                    SizedBox(
                      height: 20,
                      child: _saving
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : _errorMessage != null
                          ? Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFFF6B6B),
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            )
                          : null,
                    ),
                    const SizedBox(height: 24),

                    // Numpad
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Column(
                        children: [
                          _buildKeyRow(['1', '2', '3']),
                          const SizedBox(height: 12),
                          _buildKeyRow(['4', '5', '6']),
                          const SizedBox(height: 12),
                          _buildKeyRow(['7', '8', '9']),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(width: 80, height: 80),
                              const SizedBox(width: 12),
                              _KeyBtn(label: '0', onTap: () => _onDigit('0')),
                              const SizedBox(width: 12),
                              _KeyBtn(
                                icon: Icons.backspace_outlined,
                                onTap: _onBackspace,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Phase indicator
                    const SizedBox(height: 24),
                    if (_confirming)
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                _pin = '';
                                _firstPin = '';
                                _confirming = false;
                                _errorMessage = null;
                              }),
                        child: Text(
                          '← Back to create PIN',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((d) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _KeyBtn(label: d, onTap: () => _onDigit(d)),
        );
      }).toList(),
    );
  }
}

// ── Keypad button ─────────────────────────────────────────────────────────────

class _KeyBtn extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  const _KeyBtn({this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 80,
                height: 80,
                child: Center(
                  child: icon != null
                      ? Icon(icon, color: Colors.white, size: 26)
                      : Text(
                          label!,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shake Animation Widget ──────────────────────────────────────────────

class _ShakeWidget extends StatefulWidget {
  final Widget child;
  const _ShakeWidget({required Key key, required this.child}) : super(key: key);

  @override
  _ShakeWidgetState createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<_ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
    ]).animate(_controller);
  }

  void shake() {
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(_animation.value, 0),
        child: child,
      ),
      child: widget.child,
    );
  }
}

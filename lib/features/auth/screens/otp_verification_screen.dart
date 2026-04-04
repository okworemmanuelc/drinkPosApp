import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/utils/notifications.dart';
import 'package:reebaplus_pos/shared/services/auth_service.dart';
import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/features/auth/screens/create_pin_screen.dart';
import 'package:reebaplus_pos/features/auth/screens/login_screen.dart';
import 'package:reebaplus_pos/features/auth/screens/business_type_selection_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final UserData? user;
  final String email;
  final bool isPinReset;

  const OtpVerificationScreen({
    super.key,
    required this.user,
    required this.email,
    this.isPinReset = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final GlobalKey<_ShakeWidgetState> _shakeKey = GlobalKey();

  bool _loading = false;
  String? _errorMessage;

  // Resend cooldown: 60 seconds after each send
  int _resendCountdown = 60;
  Timer? _resendTimer;

  int _resendAttempts = 0;
  int _failedAttempts = 0;
  DateTime? _lockoutEndTime;
  bool _isLockedOut = false;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _checkLockoutStatus();
    _otpController.addListener(() {
      setState(() => _errorMessage = null);
      if (_otpController.text.trim().length == 6 &&
          !_loading &&
          !_isLockedOut) {
        _submit();
      }
    });
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  Future<void> _checkLockoutStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutTimeString = prefs.getString('otp_lockout_until');

    if (lockoutTimeString != null) {
      final lockoutTime = DateTime.parse(lockoutTimeString);
      if (DateTime.now().isBefore(lockoutTime)) {
        setState(() {
          _lockoutEndTime = lockoutTime;
          _isLockedOut = true;
          _errorMessage = 'Too many failed attempts. Try again later.';
        });
        _startLockoutTimer();
      } else {
        prefs.remove('otp_lockout_until');
      }
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_lockoutEndTime != null && DateTime.now().isAfter(_lockoutEndTime!)) {
        setState(() {
          _isLockedOut = false;
          _failedAttempts = 0;
          _errorMessage = null;
        });
        t.cancel();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  bool get _canSubmit =>
      _otpController.text.trim().length == 6 && !_loading && !_isLockedOut;

  Future<void> _submit() async {
    final otp = _otpController.text.trim();
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final error = await authService.verifyOtp(widget.email, otp);

    if (!mounted) return;

    if (error != null) {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        final prefs = await SharedPreferences.getInstance();
        final lockoutTime = DateTime.now().add(const Duration(minutes: 30));
        await prefs.setString(
          'otp_lockout_until',
          lockoutTime.toIso8601String(),
        );

        setState(() {
          _loading = false;
          _isLockedOut = true;
          _lockoutEndTime = lockoutTime;
          _errorMessage = 'Too many failed attempts. Locked for 30 minutes.';
          _otpController.clear();
        });
        _startLockoutTimer();
      } else {
        setState(() {
          _loading = false;
          _errorMessage = 'Invalid code. Please try again.';
          _otpController.clear();
        });
        _shakeKey.currentState?.shake();
      }
      return;
    }

    setState(() => _loading = false);

    // OTP verified — route based on whether the user exists locally.
    if (widget.user == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BusinessTypeSelectionScreen(email: widget.email),
        ),
      );
    } else {
      final hasPin = widget.user!.pin.isNotEmpty;
      if (hasPin && !widget.isPinReset) {
        // Existing user on a new device → enter their existing PIN.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        // New staff OR resetting PIN — create their PIN for the first time.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CreatePinScreen(user: widget.user!),
          ),
        );
      }
    }
  }

  Future<void> _resend() async {
    if (_resendAttempts >= 3) {
      AppNotification.showError(
        context,
        'Maximum resend attempts reached. Please restart.',
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() => _loading = true);
    final error = await authService.sendOtp(widget.email);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      AppNotification.showError(context, error);
    } else {
      _resendAttempts++;
      AppNotification.showSuccess(context, 'New code sent to ${widget.email}');
      _startResendTimer();
    }
  }

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];

    if (name.length <= 2) {
      return '${name.substring(0, 1)}**@$domain';
    }
    return '${name.substring(0, 2)}**@$domain';
  }

  @override
  Widget build(BuildContext context) {
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
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                28,
                40,
                28,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Logo
                  Center(
                    child: Image.asset(
                      'assets/images/reebaplus_logo.png',
                      height: 72,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.storefront,
                        size: 72,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Center(
                    child: Text(
                      'Check your email',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Enter the 6-digit code sent to\n${_maskEmail(widget.email)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // OTP input — single invisible field driving 6 styled boxes
                  _ShakeWidget(
                    key: _shakeKey,
                    child: _OtpBoxRow(
                      controller: _otpController,
                      hasError: _errorMessage != null,
                      onSubmit: _canSubmit ? _submit : null,
                      ignorePointers: _isLockedOut || _loading,
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Center(
                    child: Text(
                      'Code expires in 10 minutes',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Error message
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _errorMessage != null
                        ? Padding(
                            key: const ValueKey('err'),
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFFF6B6B),
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : const SizedBox(key: ValueKey('no-err'), height: 18),
                  ),
                  const SizedBox(height: 16),

                  AppButton(
                    text: 'Verify',
                    isLoading: _loading,
                    onPressed: _canSubmit ? _submit : null,
                  ),
                  const SizedBox(height: 20),

                  // Resend button with countdown
                  Center(
                    child: _resendCountdown > 0
                        ? Text(
                            'Resend code in 0:${_resendCountdown.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          )
                        : TextButton(
                            onPressed: (_loading || _isLockedOut)
                                ? null
                                : _resend,
                            child: Text(
                              'Resend code',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 13,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
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

// ── Six styled OTP boxes driven by a single hidden TextField ──────────────────

class _OtpBoxRow extends StatefulWidget {
  final TextEditingController controller;
  final bool hasError;
  final VoidCallback? onSubmit;
  final bool ignorePointers;

  const _OtpBoxRow({
    required this.controller,
    required this.hasError,
    this.onSubmit,
    this.ignorePointers = false,
  });

  @override
  State<_OtpBoxRow> createState() => _OtpBoxRowState();
}

class _OtpBoxRowState extends State<_OtpBoxRow> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!widget.ignorePointers) _focusNode.requestFocus();
      },
      child: Stack(
        children: [
          // Hidden text field that captures input
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => widget.onSubmit?.call(),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
          ),
          // Visible boxes
          LayoutBuilder(
            builder: (context, constraints) {
              // Fit 6 boxes with gaps into available width, capped at 46px each.
              const gap = 8.0;
              final boxSize = ((constraints.maxWidth - gap * 5) / 6).clamp(
                0.0,
                46.0,
              );
              final boxHeight = boxSize * (56 / 46);
              return ListenableBuilder(
                listenable: widget.controller,
                builder: (_, __) {
                  final text = widget.controller.text;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) {
                      final filled = i < text.length;
                      final digit = filled ? text[i] : '';
                      final isActive = i == text.length && _focusNode.hasFocus;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: EdgeInsets.only(right: i < 5 ? gap : 0),
                        width: boxSize,
                        height: boxHeight,
                        decoration: BoxDecoration(
                          color: filled
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.hasError
                                ? const Color(0xFFFF6B6B)
                                : isActive
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            digit,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

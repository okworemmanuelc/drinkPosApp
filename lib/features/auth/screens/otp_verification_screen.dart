import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/notifications.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/widgets/app_button.dart';
import 'create_pin_screen.dart';
import 'login_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final UserData user;
  final String email;

  const OtpVerificationScreen({
    super.key,
    required this.user,
    required this.email,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  // Resend cooldown: 60 seconds after each send
  int _resendCountdown = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(() => setState(() => _errorMessage = null));
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  bool get _canSubmit => _otpController.text.trim().length == 6 && !_loading;

  Future<void> _submit() async {
    final otp = _otpController.text.trim();
    setState(() { _loading = true; _errorMessage = null; });

    final error = await authService.verifyOtp(widget.email, otp);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _loading = false;
        _errorMessage = 'Invalid or expired code. Please try again.';
      });
      return;
    }

    setState(() => _loading = false);

    // OTP verified — route based on whether user already has a PIN.
    final hasPin = widget.user.pin.isNotEmpty;
    if (hasPin) {
      // Existing user on a new device → enter their existing PIN.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      // New staff — create their PIN for the first time.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => CreatePinScreen(user: widget.user)),
      );
    }
  }

  Future<void> _resend() async {
    setState(() => _loading = true);
    final error = await authService.sendOtp(widget.email);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      AppNotification.showError(context, error);
    } else {
      AppNotification.showSuccess(context, 'New code sent to ${widget.email}');
      _startResendTimer();
    }
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
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Logo
                  Center(
                    child: Image.asset(
                      'assets/images/reebaplus_logo.png',
                      height: 72,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.storefront, size: 72, color: Colors.white),
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
                      'Enter the 6-digit code sent to\n${widget.email}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // OTP input — single invisible field driving 6 styled boxes
                  _OtpBoxRow(
                    controller: _otpController,
                    hasError: _errorMessage != null,
                    onSubmit: _canSubmit ? _submit : null,
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
                            'Resend code in ${_resendCountdown}s',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          )
                        : TextButton(
                            onPressed: _loading ? null : _resend,
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

// ── Six styled OTP boxes driven by a single hidden TextField ──────────────────

class _OtpBoxRow extends StatefulWidget {
  final TextEditingController controller;
  final bool hasError;
  final VoidCallback? onSubmit;

  const _OtpBoxRow({
    required this.controller,
    required this.hasError,
    this.onSubmit,
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
      onTap: () => _focusNode.requestFocus(),
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
          ListenableBuilder(
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
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 46,
                    height: 56,
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
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';
import 'package:reebaplus_pos/core/utils/notifications.dart';
import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/features/auth/widgets/auth_background.dart';
import 'package:reebaplus_pos/features/auth/widgets/shake_widget.dart';
import 'package:reebaplus_pos/features/auth/widgets/otp_input.dart';

/// Second OTP verification screen shown after PIN entry for email-only users.
///
/// Google-authenticated users skip this screen entirely.
class PostPinOtpScreen extends ConsumerStatefulWidget {
  final UserData user;

  const PostPinOtpScreen({super.key, required this.user});

  @override
  ConsumerState<PostPinOtpScreen> createState() => _PostPinOtpScreenState();
}

class _PostPinOtpScreenState extends ConsumerState<PostPinOtpScreen> {
  final _otpController = TextEditingController();
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey();

  bool _loading = false;
  bool _verified = false;
  String? _errorMessage;

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
      if (_errorMessage != null) {
        setState(() => _errorMessage = null);
      }
      if (_otpController.text.trim().length == 6 &&
          !_loading &&
          !_isLockedOut) {
        _submit();
      }
    });
    _sendInitialOtp();
    _startResendTimer();
  }

  Future<void> _sendInitialOtp() async {
    final email = widget.user.email;
    if (email == null || email.isEmpty) return;

    final error = await ref.read(authProvider).sendOtp(email);
    if (!mounted) return;
    if (error != null) {
      AppNotification.showError(context, error);
    }
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
    final lockoutTimeString = prefs.getString('post_pin_otp_lockout_until');

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
        prefs.remove('post_pin_otp_lockout_until');
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
    final email = widget.user.email;
    if (email == null || email.isEmpty) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final error = await ref.read(authProvider).verifyOtp(email, otp);
    if (!mounted) return;

    if (error != null) {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        final prefs = await SharedPreferences.getInstance();
        final lockoutTime = DateTime.now().add(const Duration(minutes: 30));
        await prefs.setString(
          'post_pin_otp_lockout_until',
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

    // OTP verified — complete login
    setState(() {
      _loading = false;
      _verified = true;
    });

    // Brief pause to show success state before navigating.
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    ref.read(authProvider).setCurrentUser(widget.user);
    // Navigator key regeneration in main.dart handles routing automatically.
  }

  Future<void> _resend() async {
    final email = widget.user.email;
    if (email == null || email.isEmpty) return;

    if (_resendAttempts >= 3) {
      if (mounted) {
        AppNotification.showError(
          context,
          'Maximum resend attempts reached. Please restart.',
        );
      }
      return;
    }

    setState(() => _loading = true);
    final error = await ref.read(authProvider).sendOtp(email);
    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      AppNotification.showError(context, error);
    } else {
      _resendAttempts++;
      AppNotification.showSuccess(context, 'New code sent to $email');
      _startResendTimer();
    }
  }

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name.substring(0, 1)}**@$domain';
    return '${name.substring(0, 2)}**@$domain';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final email = widget.user.email ?? '';

    return AuthBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // Lock icon
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified_user_rounded,
                    size: 36,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Center(
                child: Text(
                  'Verify your identity',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Enter the 6-digit code sent to\n${_maskEmail(email)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 36),

              // OTP input
              ShakeWidget(
                key: _shakeKey,
                child: OtpBoxRow(
                  controller: _otpController,
                  hasError: _errorMessage != null,
                  onSubmit: _canSubmit ? _submit : null,
                  ignorePointers: _isLockedOut,
                  readOnly: _loading,
                  textColor: textColor,
                ),
              ),
              const SizedBox(height: 12),

              Center(
                child: Text(
                  'Code expires in 10 minutes',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
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
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox(key: ValueKey('no-err'), height: 18),
              ),
              const SizedBox(height: 16),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOut,
                child: _verified
                    ? const AppButton(
                        key: ValueKey('verified'),
                        text: 'Verified  ✓',
                        variant: AppButtonVariant.success,
                        onPressed: null,
                      )
                    : AppButton(
                        key: const ValueKey('verify'),
                        text: 'Verify & Continue',
                        isLoading: _loading,
                        onPressed: _canSubmit ? _submit : null,
                      ),
              ),
              const SizedBox(height: 20),

              // Resend
              Center(
                child: _resendCountdown > 0
                    ? Text(
                        'Resend code in 0:${_resendCountdown.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      )
                    : TextButton(
                        onPressed: (_loading || _isLockedOut) ? null : _resend,
                        child: Text(
                          'Resend code',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.75),
                            fontSize: 13,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

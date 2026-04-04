import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:reebaplus_pos/core/utils/notifications.dart';
import 'package:reebaplus_pos/shared/services/auth_service.dart';
import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/features/auth/screens/login_screen.dart';
import 'package:reebaplus_pos/features/auth/screens/otp_verification_screen.dart';
import 'package:reebaplus_pos/core/database/app_database.dart' show UserData;
import 'package:reebaplus_pos/main.dart' show supabaseReady;

class EmailEntryScreen extends StatefulWidget {
  const EmailEntryScreen({super.key});

  @override
  State<EmailEntryScreen> createState() => _EmailEntryScreenState();
}

class _EmailEntryScreenState extends State<EmailEntryScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _isEmailValid = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
  }

  void _validateEmail() {
    final email = _emailController.text.trim().toLowerCase();
    final isValid = email.contains('@') && email.contains('.');
    if (_isEmailValid != isValid) {
      setState(() => _isEmailValid = isValid);
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmail);
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim().toLowerCase();

    if (!email.contains('@') || !email.contains('.')) {
      AppNotification.showError(context, 'Enter a valid email address.');
      return;
    }

    setState(() => _loading = true);

    if (!mounted) return;

    // Run DB lookup and OTP send in parallel.
    // supabaseReady is chained inside sendOtp only — getUserByEmail starts
    // immediately so we don't block the DB query on Supabase init.
    UserData? localUser;
    String? otpError;
    bool dbCheckDone = false;
    bool otpSent = false;
    try {
      debugPrint('[EmailEntry] Starting DB + Supabase parallel tasks...');
      await Future.wait([
        authService
            .getUserByEmail(email)
            .then((u) {
              debugPrint('[EmailEntry] Local user check done: ${u != null}');
              localUser = u;
              dbCheckDone = true;
            })
            .catchError((e) {
              debugPrint('[EmailEntry] Local user check error: $e');
            }),
        supabaseReady
            .then((_) {
              debugPrint('[EmailEntry] Supabase ready. Sending OTP...');
              return authService.sendOtp(email);
            })
            .then((e) {
              debugPrint('[EmailEntry] Send OTP result: ${e ?? "Success"}');
              otpError = e;
              otpSent = true;
            })
            .catchError((e) {
              debugPrint('[EmailEntry] Supabase/OTP error: $e');
            }),
      ]).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      debugPrint(
        '[EmailEntry] Task timed out. DB: $dbCheckDone, OTP: $otpSent',
      );
      if (!dbCheckDone) {
        otpError = 'Database response delayed. Please restart the app.';
      } else {
        otpError = 'Network timeout. Please check your internet connection.';
      }
    } catch (e) {
      debugPrint('[EmailEntry] Submit error: $e');
      otpError = 'Something went wrong. Please try again.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted) return;

    if (otpError != null) {
      AppNotification.showError(context, otpError!);
      return;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            OtpVerificationScreen(user: localUser, email: email),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _goToPinDirectly() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          return FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curve),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
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
                  // Logo
                  Center(
                    child: Image.asset(
                      'assets/images/reebaplus_logo.png',
                      height: 90,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.storefront,
                        size: 90,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Reebaplus POS',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Enter your email to continue',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Email card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofocus: false,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _loading ? null : _submit(),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Terms and Privacy Policy
                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                          height: 1.5,
                        ),
                        children: const [
                          TextSpan(text: 'By continuing, you agree to our\n'),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  AppButton(
                    text: 'Send Code',
                    isLoading: _loading,
                    onPressed: (_loading || !_isEmailValid) ? null : _submit,
                  ),
                  const SizedBox(height: 20),

                  Center(
                    child: TextButton(
                      onPressed: _goToPinDirectly,
                      child: Text(
                        'Already set up on this device? Login with PIN',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
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

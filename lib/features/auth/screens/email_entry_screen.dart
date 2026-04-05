import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reebaplus_pos/core/providers/app_providers.dart';
import 'package:reebaplus_pos/core/utils/notifications.dart';
import 'package:reebaplus_pos/core/theme/app_decorations.dart';
import 'package:reebaplus_pos/shared/widgets/app_button.dart';
import 'package:reebaplus_pos/features/auth/screens/login_screen.dart';
import 'package:reebaplus_pos/features/auth/screens/otp_verification_screen.dart';
import 'package:reebaplus_pos/features/auth/widgets/auth_background.dart';
import 'package:reebaplus_pos/core/database/app_database.dart' show UserData;
import 'package:reebaplus_pos/main.dart' show supabaseReady;

class EmailEntryScreen extends ConsumerStatefulWidget {
  const EmailEntryScreen({super.key});

  @override
  ConsumerState<EmailEntryScreen> createState() => _EmailEntryScreenState();
}

class _EmailEntryScreenState extends ConsumerState<EmailEntryScreen> {
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
    final auth = ref.read(authProvider);
    UserData? localUser;
    String? otpError;
    bool dbCheckDone = false;
    bool otpSent = false;
    try {
      debugPrint('[EmailEntry] Starting DB + Supabase parallel tasks...');
      await Future.wait([
        auth
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
              return auth.sendOtp(email);
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

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return AuthBackground(
      child: SafeArea(
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
                  // In light mode, the logo might be white-on-white if not careful.
                  // We can apply a slight color filter or use an icon if needed.
                  color: isDark ? null : theme.colorScheme.primary,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.storefront, size: 90, color: textColor),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Reebaplus POS',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Enter your email to continue',
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Email card
              Container(
                decoration: AppDecorations.glassCard(context),
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _loading ? null : _submit(),
                  style: TextStyle(color: textColor),
                  decoration: AppDecorations.authInputDecoration(
                    context,
                    label: 'Email Address',
                    prefixIcon: Icons.email_outlined,
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
                      color: textColor.withValues(alpha: 0.6),
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
                      color: textColor.withValues(alpha: 0.65),
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
    );
  }
}

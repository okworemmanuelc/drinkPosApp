import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';

import 'package:reebaplus_pos/shared/services/auth_service.dart';
import 'package:reebaplus_pos/core/utils/responsive.dart';
import 'package:reebaplus_pos/core/utils/notifications.dart';
import 'package:reebaplus_pos/features/auth/screens/email_entry_screen.dart';
import 'package:reebaplus_pos/features/auth/screens/otp_verification_screen.dart';
import 'package:reebaplus_pos/shared/widgets/main_layout.dart';
import 'dart:async';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _checking = false;
  bool _biometricsAvailable = false;

  // ── Returning User & Lockout State ──────────────────────────────────────────
  UserData? _identifiedUser;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;
  String? _pinWarning;

  // ── Success animation state ────────────────────────────────────────────────
  bool _loginSuccess = false;
  UserData? _loggedInUser;
  late final AnimationController _checkAnim;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkFade;

  @override
  void initState() {
    super.initState();
    _checkAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    // Scale goes from 0 → 1 with a bouncy feel
    _checkScale = CurvedAnimation(parent: _checkAnim, curve: Curves.elasticOut);
    // Fade goes from 0 → 1 in the first half of the animation
    _checkFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _checkAnim,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _initUserAndLockoutState();
  }

  Future<void> _initUserAndLockoutState() async {
    final prefs = await SharedPreferences.getInstance();

    // Check lockout
    final lockoutMs = prefs.getInt('pin_lockout_until');
    if (lockoutMs != null) {
      final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutMs);
      if (lockoutTime.isAfter(DateTime.now())) {
        setState(() => _lockoutUntil = lockoutTime);
        _startLockoutTimer();
      } else {
        await prefs.remove('pin_lockout_until');
      }
    }

    // Identify user
    final userId = await authService.getDeviceUserId();
    if (userId != null) {
      final user = await database.warehousesDao.getUserById(userId);
      if (mounted && user != null) {
        setState(() => _identifiedUser = user);
      }
    }

    _checkBiometricAvailability();
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_lockoutUntil != null && DateTime.now().isAfter(_lockoutUntil!)) {
        timer.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pin_lockout_until');
        setState(() {
          _lockoutUntil = null;
          _failedAttempts = 0;
          _pinWarning = null;
        });
      } else {
        setState(() {}); // trigger rebuild for countdown
      }
    });
  }

  /// Checks whether the device supports biometrics and updates [_biometricsAvailable].
  /// Never shows a dialog — purely a capability check.
  Future<void> _checkBiometricAvailability() async {
    try {
      final auth = LocalAuthentication();
      final available =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (mounted) setState(() => _biometricsAvailable = available);
    } catch (_) {}
  }

  /// Called when the user explicitly taps "Sign in with Biometrics".
  Future<void> _triggerBiometrics() async {
    final auth = LocalAuthentication();
    try {
      // Check if any biometrics are enrolled on the device
      final enrolled = await auth.getAvailableBiometrics();
      if (enrolled.isEmpty) {
        if (mounted) {
          AppNotification.showError(
            context,
            'No biometrics enrolled. Please set up fingerprint or Face ID in your device settings.',
          );
        }
        return;
      }

      final authenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to log in',
        options: const AuthenticationOptions(
          stickyAuth: false,
          biometricOnly: false,
        ),
      );
      if (!mounted) return;
      if (authenticated) {
        final userId = await authService.getDeviceUserId();
        if (userId != null) {
          final user = await database.warehousesDao.getUserById(userId);
          if (user != null) _enterApp(user);
        }
      } else {
        // User cancelled or biometric not recognised — show a hint
        AppNotification.showError(
          context,
          'Biometric not recognised. Please try again or use your PIN.',
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'NotEnrolled' => 'No biometrics enrolled. Set up fingerprint or Face ID in device settings.',
        'NotAvailable' || 'HardwareUnavailable' => 'Biometric hardware is not available on this device.',
        'LockedOut' || 'PermanentlyLockedOut' => 'Biometrics locked out due to too many attempts. Use your PIN.',
        _ => 'Biometric authentication failed. Please use your PIN instead.',
      };
      AppNotification.showError(context, message);
    } catch (_) {
      if (mounted) {
        AppNotification.showError(
          context,
          'Biometric authentication failed. Please use your PIN instead.',
        );
      }
    }
  }

  @override
  void dispose() {
    _checkAnim.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  // ── PIN input helpers ──────────────────────────────────────────────────────

  void _onDigit(String digit) {
    if (_pin.length >= 6 ||
        _checking ||
        _loginSuccess ||
        _lockoutUntil != null) {
      return;
    }
    setState(() {
      _pin += digit;
    });
    if (_pin.length == 6) _submit();
  }

  void _onBackspace() {
    if (_pin.isEmpty || _checking || _loginSuccess) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _submit() async {
    setState(() => _checking = true);

    if (!mounted) return;

    List<UserData> matches;
    try {
      matches = await authService.getUsersByPin(_pin);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pin = '';
        _checking = false;
      });
      if (mounted) {
        AppNotification.showError(context, 'Login failed. Please try again.');
      }
      return;
    }

    if (!mounted) return;

    if (matches.isEmpty) {
      _failedAttempts++;
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _pin = '';
        _checking = false;

        if (_failedAttempts >= 5) {
          _lockoutUntil = DateTime.now().add(const Duration(minutes: 15));
          prefs.setInt(
            'pin_lockout_until',
            _lockoutUntil!.millisecondsSinceEpoch,
          );
          _startLockoutTimer();
        } else if (_failedAttempts >= 3) {
          _pinWarning =
              '${5 - _failedAttempts} attempts remaining before lockout.';
        }
      });

      if (mounted && _lockoutUntil == null) {
        AppNotification.showError(context, 'Wrong PIN. Please try again.');
      }
      return;
    }

    // Success reset
    _failedAttempts = 0;
    _pinWarning = null;

    if (matches.length == 1) {
      _enterApp(matches.first);
      return;
    }

    // Multiple people share this PIN — ask which one is logging in
    setState(() => _checking = false);
    if (mounted) {
      _showUserPicker(matches);
    }
  }

  /// Plays the success animation then opens the app.
  Future<void> _enterApp(UserData user) async {
    setState(() {
      _loginSuccess = true;
      _loggedInUser = user;
      _checking = false;
    });
    _checkAnim.forward();

    // Controlled delay (1.2s) to show the "Welcome" overlay and completion animation.
    // This allows the user to feel the successful entry before background loading starts.
    await Future.delayed(const Duration(milliseconds: 1200));

    authService.setCurrentUser(user);

    if (!mounted) return;

    // If LoginScreen is the home route ('/'), VLB swaps it for MainLayout — no
    // navigation needed.  But if it was pushed by the OTP flow (pushReplacement
    // removed the home route), VLB is disposed and can never fire, so we must
    // navigate explicitly.
    final isHomeRoute = ModalRoute.of(context)?.settings.name == '/';
    if (isHomeRoute) {
      // VLB will handle the swap — nothing to do here.
      return;
    }

    // LoginScreen was pushed on top of (or replacing) the home route.
    // Clear the entire stack and go straight to MainLayout.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainLayout()),
      (route) => false,
    );
  }

  /// Clears device persistence and navigates to email entry so the user can
  /// log in with a different account or on a new device.
  Future<void> _switchToEmail() async {
    await authService.clearDeviceUserId();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const EmailEntryScreen(),
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

  Future<void> _forgotPin() async {
    if (_identifiedUser == null || (_identifiedUser!.email ?? '').isEmpty) {
      AppNotification.showError(context, 'No email linked to this account.');
      return;
    }

    setState(() => _checking = true);
    final error = await authService.sendOtp(_identifiedUser!.email!);
    if (!mounted) return;
    setState(() => _checking = false);

    if (error != null) {
      AppNotification.showError(context, error);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          user: _identifiedUser,
          email: _identifiedUser!.email!,
          isPinReset: true,
        ),
      ),
    );
  }

  void _showUserPicker(List<UserData> users) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UserPickerSheet(
        users: users,
        onSelected: (user) {
          Navigator.pop(context);
          _enterApp(user);
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const bg = Colors.transparent;
    return Scaffold(
      backgroundColor: Colors.black, // fallback
      body: Stack(
        children: [
          // ── Background Image ──────────────────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/auth_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.black),
            ),
          ),

          // ── Glass Blur Layer ──────────────────────────────────────────
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),

          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _loginSuccess
                  ? _SuccessOverlay(
                      key: const ValueKey('success'),
                      user: _loggedInUser!,
                      checkScale: _checkScale,
                      checkFade: _checkFade,
                      bg: bg,
                      textColor: Colors.white,
                      subtextColor: Colors.white.withValues(alpha: 0.7),
                    )
                  : _PinPad(
                      key: const ValueKey('pinpad'),
                      pin: _pin,
                      checking: _checking,
                      identifiedUser: _identifiedUser,
                      lockoutUntil: _lockoutUntil,
                      warningText: _pinWarning,
                      bg: bg,
                      surface: Colors.white.withValues(alpha: 0.1),
                      textColor: Colors.white,
                      subtextColor: Colors.white.withValues(alpha: 0.6),
                      onDigit: _onDigit,
                      onBackspace: _onBackspace,
                      onSwitchToEmail: _switchToEmail,
                      onForgotPin: _forgotPin,
                      biometricsAvailable: _biometricsAvailable,
                      onBiometrics: _biometricsAvailable ? _triggerBiometrics : null,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Success overlay ────────────────────────────────────────────────────────

class _SuccessOverlay extends StatelessWidget {
  final UserData user;
  final Animation<double> checkScale;
  final Animation<double> checkFade;
  final Color bg;
  final Color textColor;
  final Color subtextColor;

  const _SuccessOverlay({
    super.key,
    required this.user,
    required this.checkScale,
    required this.checkFade,
    required this.bg,
    required this.textColor,
    required this.subtextColor,
  });

  Color _hexColor(BuildContext context, String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _hexColor(context, user.avatarColor);

    return Center(
      child: FadeTransition(
        opacity: checkFade,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Bouncy checkmark circle ─────────────────────────────────
            ScaleTransition(
              scale: checkScale,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: avatarColor, width: 3),
                ),
                child: Icon(Icons.check_rounded, size: 52, color: avatarColor),
              ),
            ),
            const SizedBox(height: 24),

            // ── Welcome text ─────────────────────────────────────────────
            Text(
              'Welcome, ${user.name}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Opening Reebaplus POS...',
              style: TextStyle(fontSize: 14, color: subtextColor),
            ),
            const SizedBox(height: 32),

            // ── Small loading dots ────────────────────────────────────────
            _LoadingDots(color: avatarColor),
          ],
        ),
      ),
    );
  }
}

// ── Three animated loading dots ────────────────────────────────────────────

class _LoadingDots extends StatefulWidget {
  final Color color;
  const _LoadingDots({required this.color});

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      _controllers.add(ctrl);
      // Stagger each dot by 200ms
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          ctrl.repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (_, __) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 8,
              height: 8 + _controllers[i].value * 8, // grows from 8 to 16
              decoration: BoxDecoration(
                color: widget.color.withValues(
                  alpha: 0.4 + _controllers[i].value * 0.6,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          },
        );
      }),
    );
  }
}

// ── PIN pad widget ─────────────────────────────────────────────────────────

class _PinPad extends StatelessWidget {
  final String pin;
  final bool checking;
  final UserData? identifiedUser;
  final DateTime? lockoutUntil;
  final String? warningText;
  final Color bg;
  final Color surface;
  final Color textColor;
  final Color subtextColor;
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onSwitchToEmail;
  final VoidCallback? onForgotPin;
  final bool biometricsAvailable;
  final VoidCallback? onBiometrics;

  const _PinPad({
    super.key,
    required this.pin,
    required this.checking,
    this.identifiedUser,
    this.lockoutUntil,
    this.warningText,
    required this.bg,
    required this.surface,
    required this.textColor,
    required this.subtextColor,
    required this.onDigit,
    required this.onBackspace,
    this.onSwitchToEmail,
    this.onForgotPin,
    this.biometricsAvailable = false,
    this.onBiometrics,
  });

  Color _hexColor(BuildContext context, String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Theme.of(context).colorScheme.primary;
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final isLockedOut = lockoutUntil != null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Header/Avatar ──────────────────────────────────────────
            if (identifiedUser != null) ...[
              CircleAvatar(
                radius: 40,
                backgroundColor: _hexColor(
                  context,
                  identifiedUser!.avatarColor,
                ).withValues(alpha: 0.2),
                child: Text(
                  identifiedUser!.name.isNotEmpty
                      ? identifiedUser!.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _hexColor(context, identifiedUser!.avatarColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome back, ${identifiedUser!.name.split(' ').first}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ] else ...[
              Image.asset('assets/images/reebaplus_logo.png', height: 80),
              const SizedBox(height: 16),
              Text(
                'Reebaplus POS',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],

            const SizedBox(height: 6),
            Text(
              isLockedOut
                  ? 'Device locked due to multiple failed attempts'
                  : 'Enter your 6-digit PIN to continue',
              style: TextStyle(
                fontSize: 14,
                color: isLockedOut ? Colors.redAccent : subtextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            if (isLockedOut) ...[
              // ── Lockout State ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.lock_clock_rounded,
                      color: Colors.redAccent,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _formatDuration(lockoutUntil!.difference(DateTime.now())),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Try again later',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: onSwitchToEmail,
                icon: const Icon(Icons.email_rounded, size: 18),
                label: const Text('Reset PIN with Email'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ] else ...[
              // ── Six dots ────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  final filled = i < pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                        color: filled
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),

              // ── Warning Message ────────────────────────────────────────────
              SizedBox(
                height: 32,
                child: warningText != null
                    ? Center(
                        child: Text(
                          warningText!,
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // ── Numeric keypad ───────────────────────────────────────────
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Column(
                  children: [
                    _buildKeyRow(['1', '2', '3'], surface, textColor),
                    const SizedBox(height: 12),
                    _buildKeyRow(['4', '5', '6'], surface, textColor),
                    const SizedBox(height: 12),
                    _buildKeyRow(['7', '8', '9'], surface, textColor),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 76, height: 76),
                        const SizedBox(width: 12),
                        _KeyButton(
                          label: '0',
                          surface: surface,
                          textColor: textColor,
                          onTap: () => onDigit('0'),
                        ),
                        const SizedBox(width: 12),
                        _KeyButton(
                          icon: Icons.backspace_outlined,
                          surface: surface,
                          textColor: textColor,
                          onTap: onBackspace,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Biometrics button ────────────────────────────────────────
              if (biometricsAvailable && onBiometrics != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onBiometrics,
                  icon: const Icon(Icons.fingerprint_rounded, size: 22),
                  label: const Text('Sign in with Biometrics'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.8),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ── Switch-account / Not You link ──────────────────────────────
              if (onSwitchToEmail != null)
                TextButton(
                  onPressed: onSwitchToEmail,
                  child: Text(
                    identifiedUser != null
                        ? 'Not ${identifiedUser!.name.split(' ').first}? Switch account'
                        : 'Login with a different account',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

              // ── Forgot PIN link ──────────────────────────────────────────
              if (identifiedUser != null && onForgotPin != null)
                TextButton(
                  onPressed: onForgotPin,
                  child: Text(
                    'Forgot PIN?',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> digits, Color surface, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((d) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _KeyButton(
            label: d,
            surface: surface,
            textColor: textColor,
            onTap: () => onDigit(d),
          ),
        );
      }).toList(),
    );
  }
}

// ── Single keypad button ────────────────────────────────────────────────────

class _KeyButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final Color surface;
  final Color textColor;
  final VoidCallback onTap;

  const _KeyButton({
    this.label,
    this.icon,
    required this.surface,
    required this.textColor,
    required this.onTap,
  });

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
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 76,
                height: 76,
                child: Center(
                  child: icon != null
                      ? Icon(icon, color: textColor, size: 26)
                      : Text(
                          label!,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: textColor,
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

// ── Bottom sheet when multiple users share the same PIN ────────────────────

class _UserPickerSheet extends StatelessWidget {
  final List<UserData> users;
  final ValueChanged<UserData> onSelected;

  const _UserPickerSheet({required this.users, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor =
        Theme.of(context).textTheme.bodySmall?.color ??
        Theme.of(context).iconTheme.color!;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, context.bottomInset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: subtextColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Who is logging in?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Multiple accounts share this PIN. Tap your name.',
            style: TextStyle(fontSize: 13, color: subtextColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ...users.map(
            (u) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: _hexColor(context, u.avatarColor),
                child: Text(
                  u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(
                u.name,
                style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
              ),
              subtitle: Text(
                _roleLabel(u.role),
                style: TextStyle(fontSize: 12, color: subtextColor),
              ),
              onTap: () => onSelected(u),
            ),
          ),
        ],
      ),
    );
  }

  Color _hexColor(BuildContext context, String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Theme.of(context).colorScheme.primary;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'CEO':
        return 'CEO';
      case 'manager':
        return 'Manager';
      case 'cashier':
        return 'Cashier';
      case 'stock_keeper':
        return 'Stock Keeper';
      case 'rider':
        return 'Rider';
      default:
        return role;
    }
  }
}

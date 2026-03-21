import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/services/auth_service.dart';
import '../../../core/utils/responsive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _errorMessage;
  bool _checking = false;

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
      duration: const Duration(milliseconds: 600),
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
  }

  @override
  void dispose() {
    _checkAnim.dispose();
    super.dispose();
  }

  // ── PIN input helpers ──────────────────────────────────────────────────────

  void _onDigit(String digit) {
    if (_pin.length >= 4 || _checking || _loginSuccess) return;
    setState(() {
      _pin += digit;
      _errorMessage = null;
    });
    if (_pin.length == 4) _submit();
  }

  void _onBackspace() {
    if (_pin.isEmpty || _checking || _loginSuccess) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    setState(() => _checking = true);

    List<UserData> matches;
    try {
      matches = await authService.getUsersByPin(_pin);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pin = '';
        _errorMessage = 'Login failed. Please try again.';
        _checking = false;
      });
      return;
    }

    if (!mounted) return;

    if (matches.isEmpty) {
      setState(() {
        _pin = '';
        _errorMessage = 'Wrong PIN. Please try again.';
        _checking = false;
      });
      return;
    }

    if (matches.length == 1) {
      _enterApp(matches.first);
      return;
    }

    // Multiple people share this PIN — ask which one is logging in
    setState(() => _checking = false);
    if (mounted) _showUserPicker(matches);
  }

  /// Plays the success animation then opens the app.
  void _enterApp(UserData user) {
    setState(() {
      _loginSuccess = true;
      _loggedInUser = user;
      _checking = false;
    });
    _checkAnim.forward();
    // Wait for animation to finish (600ms) + brief pause (400ms) then open app
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) authService.setCurrentUser(user);
    });
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
            child: Image.network(
              'https://images.unsplash.com/photo-1543007630-9710e4a00a20?auto=format&fit=crop&q=80&w=1935&ixlib=rb-4.0.3',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.black),
            ),
          ),
          
          // ── Glass Blur Layer ──────────────────────────────────────────
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
              ),
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
                  : Stack(
                      children: [
                        _PinPad(
                          key: const ValueKey('pinpad'),
                          pin: _pin,
                          checking: _checking,
                          errorMessage: _errorMessage,
                          bg: bg,
                          surface: Colors.white.withValues(alpha: 0.1),
                          textColor: Colors.white,
                          subtextColor: Colors.white.withValues(alpha: 0.6),
                          onDigit: _onDigit,
                          onBackspace: _onBackspace,
                        ),
                        if (_checking)
                          Positioned.fill(
                            child: _CheckingOverlay(),
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

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return blueMain;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _hexColor(user.avatarColor);

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
                child: Icon(
                  Icons.check_rounded,
                  size: 52,
                  color: avatarColor,
                ),
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
              'Opening Ribaplus POS...',
              style: TextStyle(
                fontSize: 14,
                color: subtextColor,
              ),
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
        if (mounted) ctrl.repeat(reverse: true);
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
  final String? errorMessage;
  final Color bg;
  final Color surface;
  final Color textColor;
  final Color subtextColor;
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  const _PinPad({
    super.key,
    required this.pin,
    required this.checking,
    required this.errorMessage,
    required this.bg,
    required this.surface,
    required this.textColor,
    required this.subtextColor,
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Logo ────────────────────────────────────────────────────
            Image.asset('assets/images/ribaplus_logo.png', height: 100),
            const SizedBox(height: 12),
            Text(
              'Ribaplus POS',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter your PIN to continue',
              style: TextStyle(fontSize: 14, color: subtextColor),
            ),
            const SizedBox(height: 40),

            // ── Four dots ───────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? blueMain : Colors.white.withValues(alpha: 0.1),
                    border: Border.all(
                      color: filled ? blueMain : Colors.white.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // ── Error message ────────────────────────────────────────────
            SizedBox(
              height: 20,
              child: errorMessage != null
                  ? Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        backgroundColor: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 24),

            // ── Numeric keypad ───────────────────────────────────────────
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
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
                      const SizedBox(width: 80, height: 80),
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

            const SizedBox(height: 32),

            // ── Loading indicator while checking PIN ─────────────────────
            // Removed the old small loader here as we use the overlay

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
                width: 80,
                height: 80,
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

  const _UserPickerSheet({
    required this.users,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).textTheme.bodySmall?.color ?? Theme.of(context).iconTheme.color!;

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
                backgroundColor: _hexColor(u.avatarColor),
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
                style:
                    TextStyle(fontWeight: FontWeight.w600, color: textColor),
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

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return blueMain;
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

// ── Glassy "Please wait" overlay during PIN check ──────────────────────────

class _CheckingOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'PLEASE WAIT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Authenticating...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

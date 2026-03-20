import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // The digits the user has tapped so far (max 4).
  String _pin = '';
  String? _errorMessage;
  bool _checking = false; // true while we're querying the database

  // ── PIN input helpers ─────────────────────────────────────────────────────

  void _onDigit(String digit) {
    if (_pin.length >= 4 || _checking) return;
    setState(() {
      _pin += digit;
      _errorMessage = null;
    });
    if (_pin.length == 4) _submit();
  }

  void _onBackspace() {
    if (_pin.isEmpty || _checking) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    setState(() => _checking = true);

    final matches = await authService.getUsersByPin(_pin);

    if (!mounted) return;

    if (matches.isEmpty) {
      // Wrong PIN — shake and show error
      setState(() {
        _pin = '';
        _errorMessage = 'Wrong PIN. Please try again.';
        _checking = false;
      });
      return;
    }

    if (matches.length == 1) {
      // Only one person has this PIN — log them in right away
      authService.setCurrentUser(matches.first);
      return; // main.dart will react and swap to MainLayout
    }

    // Multiple people share this PIN — ask which one is logging in
    setState(() => _checking = false);
    if (mounted) _showUserPicker(matches);
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
          authService.setCurrentUser(user);
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? dBg : lBg;
    final surface = isDark ? dSurface : lSurface;
    final textColor = isDark ? dText : lText;
    final subtextColor = isDark ? dSubtext : lSubtext;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo ──────────────────────────────────────────────────
                Image.asset(
                  'assets/images/ribaplus_logo.png',
                  height: 80,
                ),
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

                // ── Four dots ─────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _pin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? blueMain : Colors.transparent,
                        border: Border.all(
                          color: filled ? blueMain : subtextColor,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // ── Error message ─────────────────────────────────────────
                SizedBox(
                  height: 20,
                  child: _errorMessage != null
                      ? Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: danger,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 24),

                // ── Numeric keypad ────────────────────────────────────────
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
                          // Empty placeholder to keep '0' centred
                          const SizedBox(width: 80, height: 80),
                          const SizedBox(width: 12),
                          _KeyButton(
                            label: '0',
                            surface: surface,
                            textColor: textColor,
                            onTap: () => _onDigit('0'),
                          ),
                          const SizedBox(width: 12),
                          // Backspace key
                          _KeyButton(
                            icon: Icons.backspace_outlined,
                            surface: surface,
                            textColor: textColor,
                            onTap: _onBackspace,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Loading indicator shown while checking PIN ─────────────
                if (_checking)
                  const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
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
            onTap: () => _onDigit(d),
          ),
        );
      }).toList(),
    );
  }
}

// ── Single keypad button ───────────────────────────────────────────────────

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
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
    );
  }
}

// ── Bottom sheet shown when multiple users share the same PIN ─────────────

class _UserPickerSheet extends StatelessWidget {
  final List<UserData> users;
  final ValueChanged<UserData> onSelected;

  const _UserPickerSheet({
    required this.users,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? dSurface : lSurface;
    final textColor = isDark ? dText : lText;
    final subtextColor = isDark ? dSubtext : lSubtext;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
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
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
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

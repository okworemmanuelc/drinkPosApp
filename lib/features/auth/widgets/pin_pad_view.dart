import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/services/auth_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/biometric_service.dart';

class PinPadView extends StatefulWidget {
  final UserData staff;
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const PinPadView({
    super.key,
    required this.staff,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<PinPadView> createState() => _PinPadViewState();
}

class _PinPadViewState extends State<PinPadView>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  int _failures = 0;
  int _cooldownSeconds = 0;
  Timer? _timer;
  bool _isShaking = false;
  bool _isProcessing = false;
  bool _biometricAvailable = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    if (widget.staff.biometricEnabled) {
      final available = await biometricService.isAvailable;
      if (mounted) setState(() => _biometricAvailable = available);
    }
  }

  Future<void> _authenticateWithBiometric() async {
    final success =
        await biometricService.authenticate(reason: 'Unlock Ribaplus POS');
    if (success && mounted) {
      setState(() => _isProcessing = true);
      await authService.loginWithPin(widget.staff.pin);
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 300));
      widget.onSuccess();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _cooldownSeconds = 30;
      _failures = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  void _onDigitPress(String digit) {
    if (_cooldownSeconds > 0 || _isProcessing || _enteredPin.length >= 4) return;

    setState(() {
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      setState(() => _isProcessing = true);
      // Wait one frame so the 4th dot renders before the overlay appears.
      WidgetsBinding.instance.addPostFrameCallback((_) => _verifyPin());
    }
  }

  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(
          () => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
    }
  }

  Future<void> _verifyPin() async {
    final success = await authService.loginWithPin(_enteredPin);
    if (!mounted) return;

    if (success) {
      // Keep spinner visible for a beat so the transition feels intentional.
      await Future.delayed(const Duration(milliseconds: 300));
      widget.onSuccess();
    } else {
      setState(() => _isProcessing = false);
      _handleFailure();
    }
  }

  void _handleFailure() {
    setState(() {
      _failures++;
      _isShaking = true;
    });

    _shakeController
        .forward(from: 0)
        .then((_) => setState(() => _isShaking = false));

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _enteredPin = '');
        if (_failures >= 3) {
          _startCooldown();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Proportional vertical gaps — shrink naturally on smaller screens
    final gapLarge = (screenHeight * 0.03).clamp(16.0, 36.0);
    final gapMedium = (screenHeight * 0.015).clamp(8.0, 20.0);

    return Stack(
      children: [
        Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon:
                      const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                ),
                Expanded(
                  child: Text(
                    'Logging in as ${widget.staff.name}',
                    textAlign: TextAlign.center,
                    style: context.bodyLarge.copyWith(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 48), // balance back button
              ],
            ),
            SizedBox(height: gapLarge),

            // PIN dots
            _buildPinDots(),

            SizedBox(height: gapMedium),

            if (_cooldownSeconds > 0)
              Text(
                'Too many attempts. Wait $_cooldownSeconds s',
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold),
              )
            else if (_failures > 0 && _enteredPin.isEmpty)
              const Text(
                'Incorrect PIN',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold),
              )
            else
              SizedBox(height: gapMedium),

            SizedBox(height: gapLarge),

            // Num Pad
            Expanded(
              child: Column(
                children: [
                  _buildRow(['1', '2', '3']),
                  _buildRow(['4', '5', '6']),
                  _buildRow(['7', '8', '9']),
                  _buildRow([_biometricAvailable ? 'biometric' : null, '0', 'delete']),
                ],
              ),
            ),
          ],
        ),

        // Inline "Signing in…" overlay — no separate route, no flash.
        if (_isProcessing)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.75),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                  SizedBox(height: 18),
                  Text(
                    'Signing in…',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPinDots() {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final double offset = _isShaking
            ? (0.5 - (0.5 - _shakeController.value).abs()) * 20
            : 0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < _enteredPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.2),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3)),
                  boxShadow: isFilled
                      ? [
                          BoxShadow(
                              color: Colors.white.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1)
                        ]
                      : null,
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildRow(List<String?> items) {
    return Expanded(
      child: Row(
        children: items.map((item) {
          if (item == null) return const Expanded(child: SizedBox());
          if (item == 'delete') {
            return _buildKey(
              child: const Icon(FontAwesomeIcons.deleteLeft,
                  color: Colors.white70),
              onTap: _onDelete,
            );
          }
          if (item == 'biometric') {
            return _buildKey(
              child: const Icon(Icons.fingerprint,
                  color: Colors.white70, size: 28),
              onTap: _authenticateWithBiometric,
            );
          }
          return _buildKey(
            child: Text(
              item,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w300),
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
            onTap: (_cooldownSeconds > 0 || _isProcessing) ? null : onTap,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}


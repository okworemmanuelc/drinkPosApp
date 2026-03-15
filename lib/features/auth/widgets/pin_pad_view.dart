import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/services/auth_service.dart';
import '../../../core/database/app_database.dart';

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
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
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
    if (_cooldownSeconds > 0 || _enteredPin.length >= 4) return;

    setState(() {
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(
          () => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
    }
  }

  Future<void> _verifyPin() async {
    // Show loading dialog immediately to eliminate the visible lag on the
    // last digit press while the DB session write completes.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
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
    );

    final success = await authService.loginWithPin(_enteredPin);

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close dialog

    if (success) {
      widget.onSuccess();
    } else {
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
      setState(() => _enteredPin = '');
      if (_failures >= 3) {
        _startCooldown();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Proportional vertical gaps — shrink naturally on smaller screens
    final gapLarge = (screenHeight * 0.03).clamp(16.0, 36.0);
    final gapMedium = (screenHeight * 0.015).clamp(8.0, 20.0);

    return Column(
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
              _buildRow([null, '0', 'delete']),
            ],
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
            onTap: _cooldownSeconds > 0 ? null : onTap,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:onafia_pos/shared/services/auth_service.dart';
import 'package:onafia_pos/shared/services/cart_service.dart';
import 'package:onafia_pos/shared/widgets/lock_overlay.dart';

class SecurityWrapper extends StatefulWidget {
  final Widget child;

  const SecurityWrapper({super.key, required this.child});

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper> with WidgetsBindingObserver {
  Timer? _idleTimer;
  bool _isLocked = false;
  static const _idleTimeout = Duration(minutes: 15);
  static const _sessionTimeout = Duration(hours: 8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetIdleTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSessionExpiry();
    }
  }

  void _checkSessionExpiry() {
    final startTime = authService.sessionStartTime;
    if (startTime != null) {
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed >= _sessionTimeout) {
        _handleLogout();
      }
    }
  }

  void _handleLogout() {
    authService.logout();
    cartService.clear();
    if (mounted) {
      // Use popUntil to go back to the root (which should be AuthScreen)
      // or navigate to a named route if available.
      // For now, since we want to break circularity, we'll use a dynamic push if necessary
      // or just assume the app will rebuild and show AuthScreen because authService is null.
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  void _resetIdleTimer() {
    if (_isLocked) return;
    
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () {
      setState(() {
        _isLocked = true;
      });
    });
  }

  void _unlock() {
    setState(() {
      _isLocked = false;
      _resetIdleTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = authService.currentUser;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _resetIdleTimer(),
      onPanDown: (_) => _resetIdleTimer(),
      child: Stack(
        children: [
          widget.child,
          if (_isLocked && currentUser != null)
            LockOverlay(
              staff: currentUser,
              onSuccess: _unlock,
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';

class AutoLockWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const AutoLockWrapper({super.key, required this.child});

  @override
  ConsumerState<AutoLockWrapper> createState() => _AutoLockWrapperState();
}

class _AutoLockWrapperState extends ConsumerState<AutoLockWrapper>
    with WidgetsBindingObserver {
  static const String _pausedTimeKey = 'app_paused_time';
  static const int _lockMinutes = 5;
  static const int _shiftExpirationHours = 12;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final prefs = await SharedPreferences.getInstance();

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // Record time when app goes to background
      await prefs.setInt(_pausedTimeKey, DateTime.now().millisecondsSinceEpoch);
    } else if (state == AppLifecycleState.resumed) {
      final pausedMs = prefs.getInt(_pausedTimeKey);
      if (pausedMs != null) {
        final pausedTime = DateTime.fromMillisecondsSinceEpoch(pausedMs);
        final difference = DateTime.now().difference(pausedTime);
        final auth = ref.read(authProvider);

        if (difference.inHours >= _shiftExpirationHours) {
          // Massive idle time, enforce full strict logout
          if (auth.currentUser != null) {
            auth.fullLogout();
          }
        } else if (difference.inMinutes >= _lockMinutes) {
          // Idle timeout reached, force soft lock
          if (auth.currentUser != null) {
            auth.logout();
          }
        }
        await prefs.remove(_pausedTimeKey);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

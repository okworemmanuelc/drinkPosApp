import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';

class AutoLockWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const AutoLockWrapper({super.key, required this.child});

  /// Set this to true immediately before opening a system file/image picker.
  /// The auto-lock check will be skipped for that single resume event.
  static bool suppressNextResume = false;

  @override
  ConsumerState<AutoLockWrapper> createState() => _AutoLockWrapperState();
}

class _AutoLockWrapperState extends ConsumerState<AutoLockWrapper>
    with WidgetsBindingObserver {
  static const String _pausedTimeKey = 'app_paused_time';
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
    final db = ref.read(databaseProvider);

    // iOS fires `inactive` for brief interruptions the user perceives as
    // still using the app (Notification Center, Control Center, system
    // alerts, app switcher, mid-call). Only treat genuine background
    // states as a pause so those don't accrue toward the auto-lock timer.
    final isBackgrounded = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
    if (isBackgrounded) {
      if (!prefs.containsKey(_pausedTimeKey)) {
        await prefs.setInt(
          _pausedTimeKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      if (AutoLockWrapper.suppressNextResume) {
        AutoLockWrapper.suppressNextResume = false;
        await prefs.remove(_pausedTimeKey);
        return;
      }
      // Single-active-device safety net: a device that was offline during
      // the kick may have missed the realtime UPDATE. Once realtime catches
      // up post-resume, the local sessions row reflects revoked_at — this
      // verifies and triggers fullLogout with the kick snackbar if so.
      unawaited(ref.read(authProvider).verifyLocalSessionStillActive());
      final pausedMs = prefs.getInt(_pausedTimeKey);
      if (pausedMs != null) {
        final pausedTime = DateTime.fromMillisecondsSinceEpoch(pausedMs);
        final difference = DateTime.now().difference(pausedTime);
        final auth = ref.read(authProvider);

        if (difference.inHours >= _shiftExpirationHours) {
          if (auth.currentUser != null) {
            auth.fullLogout();
          }
        } else {
          final intervalStr =
              await db.settingsDao.get('auto_lock_interval_seconds');
          final autoLockSeconds = int.tryParse(intervalStr ?? '') ?? 1800;

          if (autoLockSeconds > 0 && difference.inSeconds >= autoLockSeconds) {
            if (auth.currentUser != null) {
              auth.logout();
            }
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

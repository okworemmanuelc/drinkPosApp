import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reebaplus_pos/core/theme/app_theme.dart';
import 'package:reebaplus_pos/core/theme/theme_notifier.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/features/auth/screens/login_screen.dart';
import 'package:reebaplus_pos/features/auth/screens/email_entry_screen.dart';
import 'package:reebaplus_pos/features/auth/screens/warehouse_assignment_screen.dart';
import 'package:reebaplus_pos/shared/services/auth_service.dart';
import 'package:reebaplus_pos/shared/widgets/main_layout.dart';
import 'package:reebaplus_pos/shared/widgets/auto_lock_wrapper.dart';
import 'package:reebaplus_pos/shared/widgets/force_update_wrapper.dart';

/// Shared future — completes when Supabase client is ready for OTP calls.
late final Future<void> supabaseReady;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Start Supabase in background — screens await supabaseReady before OTP calls.
  supabaseReady = Supabase.initialize(
    url: 'https://ewwyofbvfjyqqirrcaou.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV3d3lvZmJ2Zmp5cXFpcnJjYW91Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1NzM0MTgsImV4cCI6MjA4OTE0OTQxOH0.McPYfcKMT_h7j9cEE7GiutREcluXo0x2SxdLP0YsP5Q',
  ).then((_) {}).catchError((_) {});

  try {
    await database
        .customSelect('SELECT 1')
        .get()
        .timeout(const Duration(seconds: 5));
  } catch (_) {}
  markDbReady();

  await themeController.init();

  runApp(const ReebaplusPosApp());
}

class ReebaplusPosApp extends StatefulWidget {
  const ReebaplusPosApp({super.key});

  @override
  State<ReebaplusPosApp> createState() => _ReebaplusPosAppState();
}

class _ReebaplusPosAppState extends State<ReebaplusPosApp> {
  /// null = still checking SharedPreferences
  /// true  = a user has logged in on this device before → show PIN screen
  /// false = fresh device / first login → show email screen
  bool? _hasDeviceUser;

  @override
  void initState() {
    super.initState();
    _checkDeviceUser();
    authService.deviceUserIdNotifier.addListener(_onDeviceUserChanged);
  }

  void _onDeviceUserChanged() {
    if (mounted) {
      setState(
        () => _hasDeviceUser = authService.deviceUserIdNotifier.value != null,
      );
    }
  }

  Future<void> _checkDeviceUser() async {
    final userId = await authService.getDeviceUserId();
    if (mounted) {
      authService.deviceUserIdNotifier.value = userId;
      setState(() => _hasDeviceUser = userId != null);
    }
  }

  @override
  void dispose() {
    authService.deviceUserIdNotifier.removeListener(_onDeviceUserChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (_, __) {
        return ForceUpdateWrapper(
          child: AutoLockWrapper(
            child: MaterialApp(
              title: 'Reebaplus POS',
              debugShowCheckedModeBanner: false,
              builder: (context, child) {
                return GestureDetector(
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  behavior: HitTestBehavior.opaque,
                  child: child,
                );
              },
              themeMode: themeController.themeMode,
              theme: switch (themeController.designSystem) {
                DesignSystem.purple => AppTheme.purpleLight(),
                DesignSystem.amber => AppTheme.amberLight(),
                DesignSystem.green => AppTheme.greenLight(),
                DesignSystem.blue => AppTheme.light(),
              },
              darkTheme: switch (themeController.designSystem) {
                DesignSystem.purple => AppTheme.purpleDarkTheme(),
                DesignSystem.amber => AppTheme.amberDarkTheme(),
                DesignSystem.green => AppTheme.greenDarkTheme(),
                DesignSystem.blue => AppTheme.dark(),
              },
              home: ValueListenableBuilder<UserData?>(
                valueListenable: authService,
                builder: (_, user, __) {
                  if (user == null) {
                    // Still reading SharedPreferences — show branded splash.
                    if (_hasDeviceUser == null) return const _BrandedSplash();
                    // Returning user on this device → skip email, go to PIN screen.
                    // New device / fresh install → go to email entry flow.
                    return _hasDeviceUser!
                        ? const LoginScreen()
                        : const EmailEntryScreen();
                  }
                  if (user.roleTier < 5 && user.warehouseId == null) {
                    return WarehouseAssignmentScreen(user: user);
                  }
                  return const MainLayout();
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Branded loading screen shown while SharedPreferences is being read.
class _BrandedSplash extends StatelessWidget {
  const _BrandedSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/reebaplus_logo.png',
              height: 90,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.storefront, size: 90, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reebaplus POS',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

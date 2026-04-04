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

/// Shared future — completes when Supabase client is ready for OTP calls.
late final Future<void> supabaseReady;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Start init tasks in parallel — none blocks the UI.
  supabaseReady = Supabase.initialize(
    url: 'https://ewwyofbvfjyqqirrcaou.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV3d3lvZmJ2Zmp5cXFpcnJjYW91Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1NzM0MTgsImV4cCI6MjA4OTE0OTQxOH0.McPYfcKMT_h7j9cEE7GiutREcluXo0x2SxdLP0YsP5Q',
  ).then((_) {}).catchError((_) {});

  // DB warmup — triggers LazyDatabase open + onCreate. Completer guards
  // against multiple screens racing to init. markDbReady() is idempotent.
  database
      .customSelect('SELECT 1')
      .get()
      .then((_) => markDbReady())
      .catchError((_) => markDbReady());

  await themeController.init();

  // Don't await DB or Supabase here — they run in background.
  // Each screen awaits the one it needs right before use.
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
  }

  Future<void> _checkDeviceUser() async {
    final userId = await authService.getDeviceUserId();
    if (mounted) {
      setState(() => _hasDeviceUser = userId != null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (_, __) {
        return MaterialApp(
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
              errorBuilder: (_, __, ___) => const Icon(
                Icons.storefront,
                size: 90,
                color: Colors.white,
              ),
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

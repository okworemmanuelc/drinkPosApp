import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reebaplus_pos/core/theme/app_theme.dart';
import 'package:reebaplus_pos/core/theme/theme_notifier.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/database/db_wipe.dart';
import 'package:reebaplus_pos/core/providers/app_providers.dart';
import 'package:reebaplus_pos/shared/services/secure_storage_service.dart';
import 'package:reebaplus_pos/features/auth/screens/login_screen.dart';
import 'package:reebaplus_pos/features/auth/screens/email_entry_screen.dart';
import 'package:reebaplus_pos/features/auth/screens/warehouse_assignment_screen.dart';
import 'package:reebaplus_pos/shared/widgets/main_layout.dart';
import 'package:reebaplus_pos/shared/widgets/auto_lock_wrapper.dart';
import 'package:reebaplus_pos/shared/widgets/force_update_wrapper.dart';
import 'package:reebaplus_pos/shared/services/auth_service.dart';
import 'package:reebaplus_pos/features/auth/screens/success_dashboard_entry_screen.dart';
import 'package:reebaplus_pos/features/auth/screens/access_granted_screen.dart';
import 'package:reebaplus_pos/features/diagnostics/screens/schema_error_screen.dart';

/// Shared future — completes when Supabase client is ready for OTP calls.
late final Future<void> supabaseReady;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Must run before any code touches `database` (the warmup query below is the
  // first thing that opens the SQLite file via LazyDatabase). See
  // lib/core/database/db_wipe.dart for the rationale.
  await wipeLegacyDatabaseIfPresent();

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

  // Schema self-heal audit ran inside beforeOpen above. If it found drift it
  // could not repair (missing column whose ALTER TABLE failed, or a missing
  // table createTable couldn't restore), refuse to boot so DAO/sync code does
  // not run against a corrupt schema.
  final audit = database.lastSchemaAudit;
  if (audit != null && audit.fatal) {
    runApp(SchemaErrorScreen(audit: audit));
    return;
  }

  await themeController.init();

  // Migrate legacy SharedPreferences auth data to encrypted storage.
  await SecureStorageService.migrateFromSharedPreferences();

  runApp(const ProviderScope(child: ReebaplusPosApp()));
}

class ReebaplusPosApp extends ConsumerStatefulWidget {
  const ReebaplusPosApp({super.key});

  @override
  ConsumerState<ReebaplusPosApp> createState() => _ReebaplusPosAppState();
}

class _ReebaplusPosAppState extends ConsumerState<ReebaplusPosApp> {
  /// null = still checking SharedPreferences
  /// true  = a user has logged in on this device before → show PIN screen
  /// false = fresh device / first login → show email screen
  bool? _hasDeviceUser;

  /// Regenerated on auth-state changes to force MaterialApp's internal
  /// Navigator to rebuild its route stack (clears stale MainLayout).
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _checkDeviceUser();
    ref.read(authProvider).deviceUserIdNotifier.addListener(_onDeviceUserChanged);
    ref.read(authProvider).addListener(_onAuthChanged);
  }

  /// When the logged-in user changes (login or logout), regenerate the
  /// navigator key so the route stack resets to the correct auth screen.
  void _onAuthChanged() {
    if (mounted) {
      setState(() => _navigatorKey = GlobalKey<NavigatorState>());
    }
  }

  void _onDeviceUserChanged() {
    if (mounted) {
      setState(() {
        _hasDeviceUser = ref.read(authProvider).deviceUserIdNotifier.value != null;
        // Force MaterialApp's Navigator to rebuild its route stack so stale
        // screens (MainLayout) are replaced by the correct auth screen.
        _navigatorKey = GlobalKey<NavigatorState>();
      });
    }
  }

  Future<void> _checkDeviceUser() async {
    final auth = ref.read(authProvider);
    final userId = await auth.getDeviceUserId();
    if (mounted) {
      auth.deviceUserIdNotifier.value = userId;
      setState(() => _hasDeviceUser = userId != null);
    }
  }

  @override
  void dispose() {
    ref.read(authProvider).deviceUserIdNotifier.removeListener(_onDeviceUserChanged);
    ref.read(authProvider).removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final auth = ref.watch(authProvider);
    final user = auth.value;

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
          themeMode: theme.themeMode,
          theme: switch (theme.designSystem) {
            DesignSystem.purple => AppTheme.purpleLight(),
            DesignSystem.amber => AppTheme.amberLight(),
            DesignSystem.green => AppTheme.greenLight(),
            DesignSystem.blue => AppTheme.light(),
          },
          darkTheme: switch (theme.designSystem) {
            DesignSystem.purple => AppTheme.purpleDarkTheme(),
            DesignSystem.amber => AppTheme.amberDarkTheme(),
            DesignSystem.green => AppTheme.greenDarkTheme(),
            DesignSystem.blue => AppTheme.dark(),
          },
          navigatorKey: _navigatorKey,
          home: () {
            if (user == null) {
              // Still reading SharedPreferences — show branded splash.
              if (_hasDeviceUser == null) return const _BrandedSplash();
              // Returning user on this device → skip email, go to PIN screen.
              // New device / fresh install → go to email entry flow.
              return _hasDeviceUser!
                  ? const LoginScreen()
                  : const EmailEntryScreen();
            }

            // Check for special post-login screens set by BiometricSetupScreen.
            final pendingRoute = auth.pendingPostLoginRoute;
            if (pendingRoute != PostLoginRoute.none) {
              auth.pendingPostLoginRoute = PostLoginRoute.none;
              switch (pendingRoute) {
                case PostLoginRoute.successDashboard:
                  return const SuccessDashboardEntryScreen();
                case PostLoginRoute.accessGranted:
                  final pendingUser = auth.pendingPostLoginUser ?? user;
                  auth.pendingPostLoginUser = null;
                  return AccessGrantedScreen(user: pendingUser);
                case PostLoginRoute.none:
                  break;
              }
            }

            if (user.roleTier < 5 && user.warehouseId == null) {
              return WarehouseAssignmentScreen(user: user);
            }
            return const MainLayout();
          }(),
        ),
      ),
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

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
import 'package:reebaplus_pos/features/auth/screens/business_details_screen.dart';
import 'package:drift/drift.dart' as drift show OrderingMode, OrderingTerm, Value;
import 'package:reebaplus_pos/shared/widgets/main_layout.dart';
import 'package:reebaplus_pos/shared/widgets/auto_lock_wrapper.dart';
import 'package:reebaplus_pos/shared/widgets/force_update_wrapper.dart';
import 'package:reebaplus_pos/shared/services/auth_service.dart';
import 'package:reebaplus_pos/features/auth/screens/success_dashboard_entry_screen.dart';
import 'package:reebaplus_pos/features/auth/screens/access_granted_screen.dart';
import 'package:reebaplus_pos/features/auth/screens/invite_landing_screen.dart';
import 'package:reebaplus_pos/features/diagnostics/screens/schema_error_screen.dart';

import 'package:timezone/data/latest.dart' as tz;

/// Shared future — completes when Supabase client is ready for OTP calls.
late final Future<void> supabaseReady;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

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

  /// Set by [_checkDeviceUser] when an interrupted onboarding is detected.
  /// While non-null, the home builder routes the user back into onboarding
  /// at BusinessDetailsScreen with all entered data pre-filled. Cleared
  /// once the user finishes (setCurrentUser fires _onAuthChanged) or via
  /// _onDeviceUserChanged on a clean re-login.
  UserData? _onboardingResumeUser;

  /// Regenerated on auth-state changes to force MaterialApp's internal
  /// Navigator to rebuild its route stack (clears stale MainLayout).
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _checkDeviceUser();
    ref.read(authProvider).deviceUserIdNotifier.addListener(_onDeviceUserChanged);
    ref.read(authProvider).addListener(_onAuthChanged);

    // Deep-link router. Buffers any cold-start URI on the notifier; if the
    // navigator isn't mounted yet, the listener fires once it is (the
    // notifier survives across the splash → home transition).
    final router = ref.read(inviteLinkRouterProvider);
    router.start();
    router.handleColdStart();
    router.pendingUri.addListener(_onInviteLink);
  }

  void _onInviteLink() {
    final router = ref.read(inviteLinkRouterProvider);
    final uri = router.consume();
    if (uri == null) return;
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return;
    final navState = _navigatorKey.currentState;
    if (navState == null) {
      // Not mounted yet — re-buffer for the next listener tick.
      router.pendingUri.value = uri;
      return;
    }
    navState.push(
      MaterialPageRoute(builder: (_) => InviteLandingScreen(token: token)),
    );
  }

  /// When the logged-in user changes (login or logout), regenerate the
  /// navigator key so the route stack resets to the correct auth screen.
  ///
  /// This is why AuthService.value stays null throughout onboarding — calling
  /// setCurrentUser here would destroy the in-progress onboarding stack.
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
    final resumeUser = await _resolveOnboardingResume();
    if (mounted) {
      auth.deviceUserIdNotifier.value = userId;
      setState(() {
        _hasDeviceUser = userId != null;
        _onboardingResumeUser = resumeUser;
      });
    }
  }

  /// Returns the local owner UserData when the app should route back into
  /// onboarding on this launch, or null otherwise.
  ///
  /// Cheap local gate first: if no Drift `businesses` row has
  /// `onboardingComplete = false`, there's nothing to resume — most users
  /// short-circuit here and pay zero added Supabase round-trips on cold
  /// start. Only when the local mirror flags an in-progress row do we
  /// confirm against Supabase (the source of truth) before committing
  /// to the resume route.
  Future<UserData?> _resolveOnboardingResume() async {
    try {
      final db = ref.read(databaseProvider);
      final incompleteLocal = await (db.select(db.businesses)
            ..where((b) => b.onboardingComplete.equals(false))
            ..limit(1))
          .getSingleOrNull();
      if (incompleteLocal == null) return null;

      // Local says incomplete — confirm against Supabase.
      try {
        await supabaseReady;
      } catch (_) {
        return null; // Supabase unreachable; route via normal path.
      }
      final supabase = Supabase.instance.client;
      final authUserId = supabase.auth.currentUser?.id;
      if (authUserId == null) return null;

      final remote = await supabase
          .from('businesses')
          .select('id, onboarding_complete')
          .eq('id', incompleteLocal.id)
          .maybeSingle();

      if (remote == null) return null; // Server row gone — nothing to resume.
      if (remote['onboarding_complete'] == true) {
        // Server already complete; local mirror is stale. Heal locally.
        await (db.update(db.businesses)
              ..where((b) => b.id.equals(incompleteLocal.id)))
            .write(const BusinessesCompanion(
              onboardingComplete: drift.Value(true),
            ));
        return null;
      }

      // Both local and remote agree onboarding is incomplete. Pick the
      // local users row keyed off this businessId — that's the owner
      // UserData we threaded through onboarding originally.
      final owner = await (db.select(db.users)
            ..where((u) => u.businessId.equals(incompleteLocal.id))
            ..orderBy([(u) => drift.OrderingTerm(
                  expression: u.createdAt,
                  mode: drift.OrderingMode.asc,
                )])
            ..limit(1))
          .getSingleOrNull();
      return owner;
    } catch (e) {
      debugPrint('[main] _resolveOnboardingResume failed: $e');
      return null;
    }
  }

  @override
  void dispose() {
    ref.read(authProvider).deviceUserIdNotifier.removeListener(_onDeviceUserChanged);
    ref.read(authProvider).removeListener(_onAuthChanged);
    ref.read(inviteLinkRouterProvider).pendingUri.removeListener(_onInviteLink);
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
              // Resumable onboarding takes priority: if a previous attempt
              // didn't reach setCurrentUser, route back into onboarding at
              // BusinessDetailsScreen with all entered data pre-filled.
              final resumeUser = _onboardingResumeUser;
              if (resumeUser != null) {
                return BusinessDetailsScreen(user: resumeUser);
              }
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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'core/database/app_database.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/email_entry_screen.dart';
import 'features/auth/screens/warehouse_assignment_screen.dart';
import 'shared/services/auth_service.dart';
import 'shared/widgets/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Initialize Supabase for OTP email authentication.
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_PROJECT_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  // Load persisted theme preferences.
  await themeController.init();

  // Check if the DB file already exists on disk.
  // - Existing install: file present → mark ready immediately, no overlay needed.
  // - Fresh install: file absent → kick off warmup in background and let the
  //   LoginScreen "Setting up…" overlay show while onCreate seeds the data.
  // Either way runApp() fires immediately so the login screen appears at once.
  final dbDir = await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(dbDir.path, 'reebaplus_pos.sqlite'));

  if (dbFile.existsSync()) {
    // Existing install — DB is already set up, no wait needed.
    dbReady = true;
    // Still open the DB connection in the background so first PIN query is fast.
    () async { try { await database.customSelect('SELECT 1').get(); } catch (_) {} }();
  } else {
    // Fresh install — run onCreate + seed data in the background.
    // LoginScreen._waitForDb() will show the overlay until this completes.
    () async {
      try { await database.customSelect('SELECT 1').get(); dbReady = true; } catch (_) {}
    }();
  }

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
                // Still reading SharedPreferences — show a blank screen briefly.
                if (_hasDeviceUser == null) return const SizedBox.shrink();
                // Returning user on this device → skip email, go to PIN screen.
                // New device / fresh install → go to email entry flow.
                return _hasDeviceUser! ? const LoginScreen() : const EmailEntryScreen();
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

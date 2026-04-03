import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reebaplus_pos/core/theme/app_theme.dart';
import 'package:reebaplus_pos/core/theme/theme_notifier.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/features/auth/screens/login_screen.dart';
import 'package:reebaplus_pos/features/auth/screens/email_entry_screen.dart';
import 'package:reebaplus_pos/features/auth/screens/warehouse_assignment_screen.dart';
import 'package:reebaplus_pos/shared/services/auth_service.dart';
import 'package:reebaplus_pos/shared/widgets/main_layout.dart';

/// Shared future that LoginScreen can await instead of issuing its own SELECT 1.
/// Completes when the database is fully ready (tables created + essential data seeded).
late final Future<void> dbWarmup;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Fire Supabase init in the background — never blocks runApp().
  // OTP email auth is only needed in the EmailEntryScreen flow, not PIN login.
  Supabase.initialize(
    url: 'https://ewwyofbvfjyqqirrcaou.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV3d3lvZmJ2Zmp5cXFpcnJjYW91Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1NzM0MTgsImV4cCI6MjA4OTE0OTQxOH0.McPYfcKMT_h7j9cEE7GiutREcluXo0x2SxdLP0YsP5Q',
  );

  // Run theme init and DB file check in parallel.
  late final bool dbExists;
  await Future.wait([
    themeController.init(),
    getApplicationDocumentsDirectory().then((dir) {
      final file = File(p.join(dir.path, 'reebaplus_pos.sqlite'));
      dbExists = file.existsSync();
    }),
  ]);

  if (dbExists) {
    // Existing install — DB is already set up, no overlay needed.
    dbReady = true;
    // Open the connection in the background so the first PIN query is fast.
    dbWarmup = database
        .customSelect('SELECT 1')
        .get()
        .then((_) {})
        .catchError((_) {});
  } else {
    // Fresh install — onCreate will create tables + seed essential auth data.
    // LoginScreen can await dbWarmup to dismiss its overlay.
    dbWarmup = database
        .customSelect('SELECT 1')
        .get()
        .then((_) {
          dbReady = true;
        })
        .catchError((_) {
          dbReady = true;
        });
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

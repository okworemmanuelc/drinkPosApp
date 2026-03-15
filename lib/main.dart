import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';

import 'core/database/app_database.dart';
import 'shared/services/auth_service.dart';
import 'shared/services/supabase_sync_service.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/auth/screens/quick_access_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Supabase
  await Supabase.initialize(
    url: 'https://ewwyofbvfjyqqirrcaou.supabase.co',
    anonKey: 'sb_publishable_MDRuacQderDrgc2TXSKeaw_BjF0907r',
  );

  await database.resetDatabase(); // TEMPORARY: Reset database for the user
  await authService.init();
  supabaseSyncService.start();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Decide start screen
  final hasQuickAccess = await authService.hasQuickAccess();

  runApp(RibaplusPosApp(startWithQuickAccess: hasQuickAccess));
}

class RibaplusPosApp extends StatelessWidget {
  final bool startWithQuickAccess;

  const RibaplusPosApp({super.key, this.startWithQuickAccess = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) => MaterialApp(
        title: 'Ribaplus POS',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: startWithQuickAccess
            ? const QuickAccessScreen()
            : const OnboardingScreen(),
      ),
    );
  }
}

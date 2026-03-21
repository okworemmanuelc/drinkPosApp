import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'core/database/app_database.dart';
import 'features/auth/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Load persisted theme preferences.
  await themeController.init();

  // Ensure the DB is fully initialized (tables + seed data) before rendering.
  await database.customSelect('SELECT 1').get();

  runApp(const RibaplusPosApp());
}

class RibaplusPosApp extends StatelessWidget {
  const RibaplusPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (_, __) {
        final isAmber =
            themeController.designSystem == DesignSystem.amber;

        return MaterialApp(
          title: 'Ribaplus POS',
          debugShowCheckedModeBanner: false,
          themeMode: themeController.themeMode,
          theme: isAmber ? AppTheme.amberLight() : AppTheme.light(),
          darkTheme:
              isAmber ? AppTheme.amberDarkTheme() : AppTheme.dark(),
          // Show splash screen first, which will then check auth and navigate.
          home: const SplashScreen(),
        );
      },
    );
  }
}



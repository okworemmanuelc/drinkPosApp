import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'core/database/app_database.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/warehouse_assignment_screen.dart';
import 'shared/services/auth_service.dart';
import 'shared/widgets/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Load persisted theme preferences.
  await themeController.init();

  // Warm up the DB so onCreate/onUpgrade runs before the login PIN query.
  // Timeout guards against a slow first-run init blocking runApp() forever.
  try {
    await database.customSelect('SELECT 1').get()
        .timeout(const Duration(seconds: 10));
  } catch (_) {
    // DB warmup timed out or failed — proceed anyway.
    // The DB initializes lazily on the first real query.
  }

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
          home: ValueListenableBuilder<UserData?>(
            valueListenable: authService,
            builder: (_, user, __) {
              if (user == null) return const LoginScreen();
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



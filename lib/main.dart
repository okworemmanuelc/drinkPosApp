import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'core/database/app_database.dart';
import 'features/auth/screens/login_screen.dart';
import 'shared/services/auth_service.dart';
import 'shared/widgets/main_layout.dart';
import 'features/auth/screens/warehouse_assignment_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Ensure the DB is fully initialized (tables + seed data) before rendering.
  // On first run this triggers onCreate which can take a moment, but Flutter's
  // native splash screen covers the wait. Prevents login from hanging.
  await database.customSelect('SELECT 1').get();

  runApp(const RibaplusPosApp());
}

class RibaplusPosApp extends StatelessWidget {
  const RibaplusPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'Ribaplus POS',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // Watch the auth service — swap between login and the main app
        // automatically whenever a user logs in or out.
        home: ValueListenableBuilder(
          valueListenable: authService,
          builder: (_, user, __) {
            if (user == null) return const LoginScreen();
            
            // Staff below CEO level (tier 5) must have a warehouse assigned
            if (user.roleTier < 5 && user.warehouseId == null) {
              return WarehouseAssignmentScreen(user: user);
            }
            
            return const MainLayout();
          },
        ),
      ),
    );
  }
}

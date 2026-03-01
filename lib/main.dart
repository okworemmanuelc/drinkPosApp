import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'features/inventory/screens/inventory_screen.dart';
import 'features/pos/screens/pos_home_screen.dart';
import 'shared/widgets/app_drawer.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Wire up the real InventoryScreen into the drawer at startup.
  // This breaks the circular import: AppDrawer never imports InventoryScreen.
  registerInventoryScreen(() => const InventoryScreen());

  runApp(const BrewFlowApp());
}

class BrewFlowApp extends StatelessWidget {
  const BrewFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'BrewFlow POS',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const PosHomeScreen(),
      ),
    );
  }
}

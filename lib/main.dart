import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'shared/widgets/main_layout.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  runApp(const BrewFlowApp());
}

class BrewFlowApp extends StatelessWidget {
  const BrewFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) => MaterialApp(
        title: 'BrewFlow POS',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const MainLayout(),
      ),
    );
  }
}

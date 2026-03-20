import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';

import 'core/database/app_database.dart';
import 'shared/widgets/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Warm up the DB isolate immediately — runs in background while Flutter renders
  database.customSelect('SELECT 1').get().ignore();

  runApp(const RibaplusPosApp());
}

class RibaplusPosApp extends StatelessWidget {
  const RibaplusPosApp({super.key});

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
        home: const MainLayout(),
      ),
    );
  }
}

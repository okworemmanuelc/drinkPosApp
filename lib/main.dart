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

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

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
        home: const _AppStartup(),
      ),
    );
  }
}

class _AppStartup extends StatefulWidget {
  const _AppStartup();

  @override
  State<_AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<_AppStartup> {
  String _status = 'Starting…';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _status = 'Connecting…');
    await Supabase.initialize(
      url: 'https://ewwyofbvfjyqqirrcaou.supabase.co',
      anonKey: 'sb_publishable_MDRuacQderDrgc2TXSKeaw_BjF0907r',
    );

    setState(() => _status = 'Loading account…');
    await authService.init();
    supabaseSyncService.start();

    setState(() => _status = 'Ready');
    final existingUsers = await database.select(database.users).get();
    final isNewUser = existingUsers.isEmpty;
    final hasQuickAccess =
        isNewUser ? false : await authService.hasQuickAccess();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => hasQuickAccess
            ? const QuickAccessScreen()
            : const OnboardingScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/ribaplus_logo.png',
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF60A5FA),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

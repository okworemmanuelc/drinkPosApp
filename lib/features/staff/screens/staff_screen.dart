import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../shared/widgets/shared_scaffold.dart';
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';

class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;

  @override
  Widget build(BuildContext context) {
    return SharedScaffold(
      activeRoute: 'staff',
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: const MenuButton(),
        title: const AppBarHeader(
          icon: FontAwesomeIcons.usersGear,
          title: 'Staff',
          subtitle: 'Management',
        ),
        actions: [
          const NotificationBell(),
          SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.usersGear,
              size: 64,
              color: blueMain.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Staff Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Coming Soon in Phase 4',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

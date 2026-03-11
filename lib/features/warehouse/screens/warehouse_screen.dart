import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../shared/widgets/shared_scaffold.dart';
import '../../../shared/widgets/menu_button.dart';
import '../../../shared/widgets/app_bar_header.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';

class WarehouseScreen extends StatelessWidget {
  const WarehouseScreen({super.key});

  bool get _isDark => themeNotifier.value == ThemeMode.dark;
  Color get _bg => _isDark ? dBg : lBg;
  Color get _surface => _isDark ? dSurface : lSurface;

  @override
  Widget build(BuildContext context) {
    return SharedScaffold(
      activeRoute: 'warehouse',
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: const MenuButton(),
        title: const AppBarHeader(
          icon: FontAwesomeIcons.warehouse,
          title: 'Warehouse',
          subtitle: 'Inventory Management',
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.warehouse,
              size: 64,
              color: blueMain.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Manage Warehouse',
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

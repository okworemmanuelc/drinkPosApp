import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/utils/responsive.dart';

class StaffPlaceholderScreen extends StatelessWidget {
  const StaffPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, child) {
        final isDark = mode == ThemeMode.dark;
        final bg = isDark ? dBg : lBg;
        final surface = isDark ? dSurface : lSurface;
        final text = isDark ? dText : lText;

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: surface,
            elevation: 0,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: Icon(Icons.menu, color: text),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: Text(
              'Staff',
              style: TextStyle(
                color: text,
                fontSize: context.getRFontSize(18),
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          body: Center(
            child: Text(
              'Staff Management (Coming Soon)',
              style: TextStyle(color: text, fontSize: context.getRFontSize(16)),
            ),
          ),
        );
      },
    );
  }
}

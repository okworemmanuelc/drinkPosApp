import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme_notifier.dart';
import '../../core/utils/responsive.dart';

class AppBarHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const AppBarHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        final bool isDark = mode == ThemeMode.dark;
        final Color text = isDark ? dText : lText;

        return Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.getRSize(8)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [blueLight, blueMain]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: blueMain.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: context.getRSize(16),
              ),
            ),
            SizedBox(width: context.getRSize(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: context.getRFontSize(18),
                        fontWeight: FontWeight.w800,
                        color: text,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: context.getRFontSize(11),
                      color: blueMain,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

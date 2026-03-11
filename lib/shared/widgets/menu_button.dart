import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme_notifier.dart';

class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        final bool isDark = mode == ThemeMode.dark;
        final Color text = isDark ? dText : lText;

        return Builder(
          builder: (ctx) => InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Scaffold.of(ctx).openDrawer(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 2.5,
                    width: context.getRSize(22),
                    decoration: BoxDecoration(
                      color: text,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    height: 2.5,
                    width: context.getRSize(16),
                    decoration: BoxDecoration(
                      color: blueMain,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    height: 2.5,
                    width: context.getRSize(22),
                    decoration: BoxDecoration(
                      color: text,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

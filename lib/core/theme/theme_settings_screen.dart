import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:reebaplus_pos/core/utils/responsive.dart';
import 'package:reebaplus_pos/core/theme/theme_notifier.dart';
import 'package:reebaplus_pos/core/theme/colors.dart';

/// Full-screen theme settings page. Pushed from the drawer.
class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
        centerTitle: false,
      ),
      body: ListenableBuilder(
        listenable: themeController,
        builder: (_, __) {
          return ListView(
            padding: EdgeInsets.symmetric(
              horizontal: context.getRSize(20),
              vertical: context.getRSize(24),
            ),
            children: [
              // ── Section: Design System ──────────────────────────────────
              Text(
                'Design System',
                style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: context.getRSize(12)),
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _DesignSystemCard(
                          label: 'Blue Classic',
                          swatchColors: const [blueMain, blueDark, blueLight],
                          isActive: themeController.designSystem ==
                              DesignSystem.blue,
                          activeColor: blueMain,
                          onTap: () => themeController
                              .setDesignSystem(DesignSystem.blue),
                        ),
                      ),
                      SizedBox(width: context.getRSize(12)),
                      Expanded(
                        child: _DesignSystemCard(
                          label: 'Amber Ribaplus',
                          swatchColors: const [
                            amberPrimary,
                            amberDark,
                            Color(0xFFFFBF4A),
                          ],
                          isActive: themeController.designSystem ==
                              DesignSystem.amber,
                          activeColor: amberPrimary,
                          onTap: () => themeController
                              .setDesignSystem(DesignSystem.amber),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.getRSize(12)),
                  Row(
                    children: [
                      Expanded(
                        child: _DesignSystemCard(
                          label: 'Purple Violet',
                          swatchColors: const [
                            purplePrimary,
                            purpleDark,
                            Color(0xFFA78BFA),
                          ],
                          isActive: themeController.designSystem ==
                              DesignSystem.purple,
                          activeColor: purplePrimary,
                          onTap: () => themeController
                              .setDesignSystem(DesignSystem.purple),
                        ),
                      ),
                      SizedBox(width: context.getRSize(12)),
                      Expanded(
                        child: _DesignSystemCard(
                          label: 'Green Forest',
                          swatchColors: const [
                            greenPrimary,
                            greenDark,
                            Color(0xFF6EE7B7),
                          ],
                          isActive: themeController.designSystem ==
                              DesignSystem.green,
                          activeColor: greenPrimary,
                          onTap: () => themeController
                              .setDesignSystem(DesignSystem.green),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: context.getRSize(32)),

              // ── Section: Mode ───────────────────────────────────────────
              Text(
                'Appearance Mode',
                style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: context.getRSize(12)),
              _ModeTile(
                icon: FontAwesomeIcons.sun,
                label: 'Light',
                isActive: themeController.themeMode == ThemeMode.light,
                onTap: () => themeController.setTheme(ThemeMode.light),
              ),
              SizedBox(height: context.getRSize(8)),
              _ModeTile(
                icon: FontAwesomeIcons.moon,
                label: 'Dark',
                isActive: themeController.themeMode == ThemeMode.dark,
                onTap: () => themeController.setTheme(ThemeMode.dark),
              ),
              SizedBox(height: context.getRSize(8)),
              _ModeTile(
                icon: FontAwesomeIcons.desktop,
                label: 'System',
                isActive: themeController.themeMode == ThemeMode.system,
                onTap: () => themeController.setTheme(ThemeMode.system),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Design System Card
// ─────────────────────────────────────────────────────────────────────────────

class _DesignSystemCard extends StatelessWidget {
  final String label;
  final List<Color> swatchColors;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _DesignSystemCard({
    required this.label,
    required this.swatchColors,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(context.getRSize(16)),
        decoration: BoxDecoration(
          color: t.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? activeColor : t.dividerColor,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color swatches row
            Row(
              children: [
                for (int i = 0; i < swatchColors.length; i++) ...[
                  Container(
                    width: context.getRSize(28),
                    height: context.getRSize(28),
                    decoration: BoxDecoration(
                      color: swatchColors[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: t.dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  if (i < swatchColors.length - 1)
                    SizedBox(width: context.getRSize(6)),
                ],
                const Spacer(),
                if (isActive)
                  Container(
                    width: context.getRSize(24),
                    height: context.getRSize(24),
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: context.getRSize(14),
                      color: Colors.black,
                    ),
                  ),
              ],
            ),
            SizedBox(height: context.getRSize(12)),
            Text(
              label,
              style: t.textTheme.titleSmall?.copyWith(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? activeColor : t.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Appearance Mode Tile
// ─────────────────────────────────────────────────────────────────────────────

class _ModeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeTile({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primary = t.colorScheme.primary;
    return Material(
      color: isActive ? primary.withValues(alpha: 0.1) : t.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.getRSize(16),
            vertical: context.getRSize(14),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? primary : t.dividerColor,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: context.getRSize(18),
                color: isActive ? primary : t.iconTheme.color,
              ),
              SizedBox(width: context.getRSize(14)),
              Expanded(
                child: Text(
                  label,
                  style: t.textTheme.bodyLarge?.copyWith(
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? primary : t.colorScheme.onSurface,
                  ),
                ),
              ),
              if (isActive)
                Icon(
                  Icons.check_circle,
                  size: context.getRSize(20),
                  color: primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}



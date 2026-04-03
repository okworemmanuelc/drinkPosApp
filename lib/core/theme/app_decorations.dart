import 'package:flutter/material.dart';
import 'package:reebaplus_pos/core/theme/colors.dart';

/// Reusable decorations for the Ribaplus design system.
class AppDecorations {
  AppDecorations._();

  /// Amber gradient box decoration (for buttons, logo, flash button, etc.)
  static BoxDecoration amberGradient({double radius = 12}) => BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [amberPrimary, amberDark],
    ),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: const [
      BoxShadow(color: amberGlow, blurRadius: 16, offset: Offset(0, 4)),
    ],
  );

  /// Surface card decoration — adapts to current theme.
  static BoxDecoration surfaceCard(
    BuildContext context, {
    double radius = 20,
  }) =>
      BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Theme.of(context).dividerColor),
      );
}

/// A 2 px top-edge shimmer line (amber gradient) that fades from
/// transparent → amberPrimary → transparent.
class AmberGlowLine extends StatelessWidget {
  final double height;
  const AmberGlowLine({super.key, this.height = 2});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            amberPrimary,
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

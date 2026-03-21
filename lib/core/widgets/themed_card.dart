import 'package:flutter/material.dart';
import '../theme/app_decorations.dart';

/// A surface card with border, radius 20, optional amber glow line.
class ThemedCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final bool showGlowLine;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ThemedCard({
    super.key,
    required this.child,
    this.radius = 20,
    this.showGlowLine = false,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: AppDecorations.surfaceCard(context, radius: radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showGlowLine) const AmberGlowLine(),
            Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

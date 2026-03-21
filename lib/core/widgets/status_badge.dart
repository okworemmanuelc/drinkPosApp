import 'package:flutter/material.dart';
import '../theme/colors.dart';

enum BadgeVariant { amber, red, green }

/// Small pill badge with text.
class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.amber,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      BadgeVariant.amber => (amberPrimary.withValues(alpha: 0.15), amberPrimary),
      BadgeVariant.red   => (dangerRed.withValues(alpha: 0.15), dangerRed),
      BadgeVariant.green => (successGreen.withValues(alpha: 0.15), successGreen),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

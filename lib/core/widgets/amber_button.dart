import 'package:flutter/material.dart';
import 'package:reebaplus_pos/core/theme/app_decorations.dart';

/// Full-width gradient button with primary glow shadow.
/// Named AmberButton for legacy reasons, but now follows theme.
class AmberButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double radius;
  final double height;
  final bool isLoading;

  const AmberButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.radius = 12,
    this.height = 48,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    // ensure onPrimary is never transparent for high contrast on the gradient
    final textColor = onPrimary != Colors.transparent
        ? onPrimary
        : Colors.white;

    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        height: height,
        decoration: AppDecorations.primaryGradient(context, radius: radius),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: textColor,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: textColor),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

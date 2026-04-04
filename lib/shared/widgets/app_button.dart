import 'package:flutter/material.dart';
import 'package:reebaplus_pos/core/utils/responsive.dart';
import 'package:reebaplus_pos/core/theme/animations.dart';

enum AppButtonVariant { primary, secondary, outline, danger, ghost }

enum AppButtonSize { xsmall, small, normal, large }

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final IconData? trailingIcon;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final AppButtonSize size;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.normal,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.trailingIcon,
    this.width,
    this.height,
    this.padding,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final bool isDisabled = widget.onPressed == null || widget.isLoading;

    // Define colors based on variant
    Color? bgColor;
    Color textColor;
    BorderSide? border;
    List<Color>? gradient;

    switch (widget.variant) {
      case AppButtonVariant.primary:
        final primary = t.colorScheme.primary;
        final secondary = t.colorScheme.secondary;
        // Use a gradient that blends primary and secondary (or a darkened primary as fallback)
        gradient = [
          secondary != primary ? secondary : primary.withValues(alpha: 0.8),
          primary,
        ];
        textColor = t.colorScheme.onPrimary != Colors.transparent
            ? t.colorScheme.onPrimary
            : Colors.white;
        break;
      case AppButtonVariant.secondary:
        bgColor = t.colorScheme.primary.withValues(alpha: 0.12);
        textColor = t.colorScheme.primary;
        break;
      case AppButtonVariant.outline:
        bgColor = Colors.transparent;
        textColor = t.colorScheme.primary;
        border = BorderSide(color: t.colorScheme.primary, width: 1.5);
        break;
      case AppButtonVariant.danger:
        bgColor = t.colorScheme.error.withValues(alpha: 0.1);
        textColor = t.colorScheme.error;
        break;
      case AppButtonVariant.ghost:
        bgColor = Colors.transparent;
        textColor = t.textTheme.bodyMedium?.color ?? t.colorScheme.onSurface;
        break;
    }

    if (isDisabled && widget.variant == AppButtonVariant.primary) {
      gradient = [Colors.grey.shade400, Colors.grey.shade500];
    } else if (isDisabled) {
      bgColor = Colors.grey.withValues(alpha: 0.1);
      textColor = Colors.grey;
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: context.getRSize(16),
            height: context.getRSize(16),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          ),
          SizedBox(width: context.getRSize(12)),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: context.getRSize(18), color: textColor),
          SizedBox(width: context.getRSize(10)),
        ],
        Flexible(
          child: Text(
            widget.text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              color: textColor,
              fontSize: context.getRFontSize(
                widget.size == AppButtonSize.xsmall
                    ? 11
                    : (widget.size == AppButtonSize.small
                          ? 13
                          : (widget.size == AppButtonSize.large ? 17 : 15)),
              ),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ),
        if (!widget.isLoading && widget.trailingIcon != null) ...[
          SizedBox(width: context.getRSize(10)),
          Icon(
            widget.trailingIcon,
            size: context.getRSize(18),
            color: textColor,
          ),
        ],
      ],
    );

    return Opacity(
      opacity: isDisabled ? 0.7 : 1.0,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedScale(
          scale: _isPressed ? AppAnimations.buttonPressedScale : 1.0,
          duration: AppAnimations.fast,
          curve: AppAnimations.defaultCurve,
          child: Container(
            width: widget.isFullWidth
                ? (widget.width ?? double.infinity)
                : widget.width,
            height:
                widget.height ??
                context.getRSize(
                  widget.size == AppButtonSize.xsmall
                      ? 32
                      : (widget.size == AppButtonSize.small
                            ? 40
                            : (widget.size == AppButtonSize.large ? 60 : 54)),
                ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: gradient != null
                  ? LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: gradient == null ? bgColor : null,
              border: border != null ? Border.fromBorderSide(border) : null,
              boxShadow:
                  widget.variant == AppButtonVariant.primary && !isDisabled
                  ? [
                      BoxShadow(
                        color: t.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isDisabled ? null : widget.onPressed,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding:
                      widget.padding ??
                      EdgeInsets.symmetric(horizontal: context.getRSize(16)),
                  child: Center(child: content),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme_notifier.dart';

class FluidMenuItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Widget? leading;

  const FluidMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.leading,
  });
}

class FluidMenu<T> extends StatelessWidget {
  final T? value;
  final List<FluidMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? placeholder;
  final String? label;
  final bool isExpanded;
  final double? width;
  final Widget? trigger;

  const FluidMenu({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.placeholder,
    this.label,
    this.isExpanded = true,
    this.width,
    this.trigger,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        final bool isDark = mode == ThemeMode.dark;
        final Color surface = isDark ? dSurface : lSurface;

        final Color text = isDark ? dText : lText;
        final Color subtext = isDark ? dSubtext : lSubtext;
        final Color border = isDark ? dBorder : lBorder;

        final selectedItem = items.cast<FluidMenuItem<T>?>().firstWhere(
              (item) => item?.value == value,
              orElse: () => null,
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null) ...[
              Text(
                label!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: subtext,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
            ],
            MenuAnchor(
              builder: (context, controller, child) {
                if (trigger != null) {
                  return InkWell(
                    onTap: () => controller.isOpen ? controller.close() : controller.open(),
                    borderRadius: BorderRadius.circular(14),
                    child: trigger,
                  );
                }
                // MenuAnchor measures its builder in an overlay with
                // unconstrained BoxConstraints. Use LayoutBuilder so
                // we only stretch when real (finite) constraints exist.
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final bool bounded = constraints.maxWidth.isFinite;
                    return InkWell(
                      onTap: () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: bounded && isExpanded ? constraints.maxWidth : width,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
                          children: [
                            if (bounded)
                              Expanded(
                                child: Text(
                                  selectedItem?.label ?? placeholder ?? 'Select option',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: selectedItem != null ? text : subtext,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            else
                              Text(
                                selectedItem?.label ?? placeholder ?? 'Select option',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selectedItem != null ? text : subtext,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: blueMain,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              menuChildren: items.map((item) {
                final bool isSelected = item.value == value;
                return MenuItemButton(
                  onPressed: () => onChanged(item.value),
                  style: MenuItemButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    backgroundColor: isSelected ? blueMain.withValues(alpha: 0.08) : Colors.transparent,
                  ),
                  leadingIcon: item.leading ?? (item.icon != null
                      ? Icon(item.icon, size: 18, color: isSelected ? blueMain : subtext)
                      : null),
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? blueMain : text,
                    ),
                  ),
                );
              }).toList(),
              style: MenuStyle(
                backgroundColor: WidgetStatePropertyAll(surface),
                surfaceTintColor: WidgetStatePropertyAll(surface),
                elevation: const WidgetStatePropertyAll(16),
                shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.25)),
                side: WidgetStatePropertyAll(BorderSide(color: border.withValues(alpha: 0.5))),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
          ],
        );
      },
    );
  }
}


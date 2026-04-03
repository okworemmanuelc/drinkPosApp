import 'package:flutter/material.dart';

import 'package:reebaplus_pos/core/utils/responsive.dart';

class StaffPlaceholderScreen extends StatelessWidget {
  const StaffPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, child) {
        
        final bg = Theme.of(context).scaffoldBackgroundColor;
        final surface = Theme.of(context).colorScheme.surface;
        final text = Theme.of(context).colorScheme.onSurface;

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



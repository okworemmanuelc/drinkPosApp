import 'package:flutter/material.dart';
import 'app_drawer.dart';

class SharedScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final String activeRoute;

  const SharedScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.backgroundColor,
    required this.activeRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      drawer: AppDrawer(activeRoute: activeRoute),
      body: Builder(
        builder: (innerContext) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            // Right swipe detection
            if (details.primaryVelocity! > 300) {
              Scaffold.of(innerContext).openDrawer();
            }
          },
          child: body,
        ),
      ),
    );
  }
}

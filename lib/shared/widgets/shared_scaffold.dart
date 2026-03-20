import 'package:flutter/material.dart';
import 'app_drawer.dart';
import 'menu_button.dart';

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
    final bool isPrimaryRoute = [
      'pos',
      'inventory',
      'orders',
      'cart',
    ].contains(activeRoute);

    return Scaffold(
      appBar:
          appBar ?? AppBar(leading: isPrimaryRoute ? const MenuButton() : null),
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      drawer: AppDrawer(activeRoute: activeRoute),
      body: Builder(
        builder: (innerContext) => NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // Handle overscroll at the edges (e.g., TabBarView first tab)
            if (notification is OverscrollNotification) {
              if (notification.overscroll < 0 &&
                  notification.metrics.axis == Axis.horizontal) {
                Scaffold.of(innerContext).openDrawer();
                return true;
              }
            }
            // Handle cases where scroll is at edge but doesn't trigger overscroll (e.g. ClampingScrollPhysics)
            if (notification is ScrollUpdateNotification) {
              if (notification.metrics.pixels <= 0 && 
                  notification.scrollDelta != null && 
                  notification.scrollDelta! < -10 && 
                  notification.metrics.axis == Axis.horizontal) {
                // Only open if we are at the very start and trying to scroll further left
                // Some physics don't overscroll but we can see the intent
              }
            }
            return false;
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              // Right swipe detection for non-scrollable areas
              // Use a reasonable velocity threshold
              if ((details.primaryVelocity ?? 0) > 300) {
                Scaffold.of(innerContext).openDrawer();
              }
            },
            child: body,
          ),
        ),
      ),
    );
  }
}

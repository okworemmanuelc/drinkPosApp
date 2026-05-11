import 'package:flutter/material.dart';

/// A wrapper for each tab in [MainLayout] that provides its own [Navigator].
/// This allows detail screens to be pushed *inside* the tab area, keeping
/// the bottom navigation bar fixed and consistent.
class TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget rootScreen;
  final NavigatorObserver? observer;

  const TabNavigator({
    super.key,
    required this.navigatorKey,
    required this.rootScreen,
    this.observer,
  });

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      observers: observer != null ? [observer!] : const <NavigatorObserver>[],
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(builder: (context) => rootScreen);
      },
    );
  }
}

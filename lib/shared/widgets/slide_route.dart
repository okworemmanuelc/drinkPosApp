import 'package:flutter/material.dart';

const _kDuration = Duration(milliseconds: 280);
const _kCurve = Curves.easeOutCubic;

Route<T> slideDownRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: _kDuration,
    reverseTransitionDuration: _kDuration,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final offset = Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).chain(CurveTween(curve: _kCurve)).animate(animation);
      return SlideTransition(position: offset, child: child);
    },
  );
}

Route<T> slideLeftRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: _kDuration,
    reverseTransitionDuration: _kDuration,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final offset = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: _kCurve)).animate(animation);
      return SlideTransition(position: offset, child: child);
    },
  );
}

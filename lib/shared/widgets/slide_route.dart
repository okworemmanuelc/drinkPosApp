import 'package:flutter/material.dart';

const _kForward = Duration(milliseconds: 500);
const _kReverse = Duration(milliseconds: 280);
const _kCurve = Curves.fastOutSlowIn;

Route<T> slideDownRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: _kForward,
    reverseTransitionDuration: _kReverse,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: _kCurve);
      final offset = Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(curved);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(position: offset, child: child),
      );
    },
  );
}

Route<T> slideLeftRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: _kForward,
    reverseTransitionDuration: _kReverse,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: _kCurve);
      final offset = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(curved);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(position: offset, child: child),
      );
    },
  );
}

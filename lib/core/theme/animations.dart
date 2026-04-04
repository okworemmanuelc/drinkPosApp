import 'package:flutter/material.dart';

class AppAnimations {
  AppAnimations._();

  // Durations
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  // Curves
  static const Curve defaultCurve = Curves.easeInOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve emphasizeCurve = Curves.easeOutBack;

  // Values
  static const double buttonPressedScale = 0.97;
}

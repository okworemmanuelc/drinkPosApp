import 'package:flutter/material.dart';

/// Baseline width used for responsive calculations (iPhone SE / standard Android).
const double _kBaseWidth = 375.0;

/// Scales [baseSize] relative to the device's screen width.
/// On a 375px-wide device, returns [baseSize] unchanged.
/// On wider/narrower screens, scales linearly.
double rFontSize(BuildContext context, double baseSize) {
  final sw = MediaQuery.of(context).size.width;
  return baseSize * (sw / _kBaseWidth);
}

/// Returns a fraction of the screen width.
double rWidth(BuildContext context, double fraction) {
  return MediaQuery.of(context).size.width * fraction;
}

/// Returns a fraction of the screen height.
double rHeight(BuildContext context, double fraction) {
  return MediaQuery.of(context).size.height * fraction;
}

/// Scales a fixed pixel value by the screen-width ratio.
double rSize(BuildContext context, double basePixels) {
  final sw = MediaQuery.of(context).size.width;
  return basePixels * (sw / _kBaseWidth);
}

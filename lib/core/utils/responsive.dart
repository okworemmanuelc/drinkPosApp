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

/// Extension on BuildContext to easily access responsive dimensions
extension ResponsiveHelper on BuildContext {
  /// Returns the width of the screen.
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Returns the height of the screen.
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Breakpoints for responsive design
  bool get isPhone => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1024;
  bool get isDesktop => screenWidth >= 1024;

  /// Scales a base font size relative to screen width.
  double getRFontSize(double baseSize) => baseSize * (screenWidth / _kBaseWidth);

  /// Scales a fixed pixel value by the screen-width ratio.
  double getRSize(double basePixels) => basePixels * (screenWidth / _kBaseWidth);

  /// Returns a fraction of the screen width.
  double getRWidth(double fraction) => screenWidth * fraction;

  /// Returns a fraction of the screen height.
  double getRHeight(double fraction) => screenHeight * fraction;

  /// Returns EdgeInsets with scaled padding.
  EdgeInsets rPadding(double base) => EdgeInsets.all(getRSize(base));
  
  /// Returns symmetric EdgeInsets with scaled padding.
  EdgeInsets rPaddingSymmetric({double horizontal = 0, double vertical = 0}) => 
      EdgeInsets.symmetric(horizontal: getRSize(horizontal), vertical: getRSize(vertical));
      
  /// Returns directional EdgeInsets with scaled padding.
  EdgeInsets rPaddingOnly({double left = 0, double top = 0, double right = 0, double bottom = 0}) =>
      EdgeInsets.only(left: getRSize(left), top: getRSize(top), right: getRSize(right), bottom: getRSize(bottom));
}

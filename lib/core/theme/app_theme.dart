import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData light() => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: lBg,
    primaryColor: blueMain,
    colorScheme: const ColorScheme.light(
      primary: blueMain,
      secondary: blueLight,
      surface: lSurface,
      onSurface: lText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lSurface,
      foregroundColor: lText,
      elevation: 0,
      centerTitle: false,
    ),
    cardColor: lSurface,
    dividerColor: lBorder,
    chipTheme: ChipThemeData(
      backgroundColor: lCard,
      selectedColor: lText,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: lText, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(color: lText),
      bodySmall: TextStyle(color: lSubtext),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  static ThemeData dark() => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: dBg,
    primaryColor: blueMain,
    colorScheme: const ColorScheme.dark(
      primary: blueMain,
      secondary: blueLight,
      surface: dSurface,
      onSurface: dText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: dSurface,
      foregroundColor: dText,
      elevation: 0,
      centerTitle: false,
    ),
    cardColor: dCard,
    dividerColor: dBorder,
    chipTheme: ChipThemeData(
      backgroundColor: dCard,
      selectedColor: blueMain,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: dText, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(color: dText),
      bodySmall: TextStyle(color: dSubtext),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

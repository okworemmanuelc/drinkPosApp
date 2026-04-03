import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:reebaplus_pos/core/theme/colors.dart';

class AppTheme {
  AppTheme._();

  // ═══════════════════════════════════════════════════════════════════════════
  // BLUE CLASSIC (original)
  // ═══════════════════════════════════════════════════════════════════════════

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lBg,
    primaryColor: blueMain,
    colorScheme: const ColorScheme.light(
      primary: blueMain,
      secondary: blueLight,
      surface: lSurface,
      onSurface: lText,
      error: danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lSurface,
      foregroundColor: lText,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: kToolbarHeight + 12,
      shadowColor: lBorder,
      surfaceTintColor: Colors.transparent,
      shape: Border(
        bottom: BorderSide(color: lBorder, width: 1.5),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: lSurface,
      selectedItemColor: blueMain,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    cardColor: lSurface,
    cardTheme: CardThemeData(
      color: lSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerColor: lBorder,
    chipTheme: ChipThemeData(
      backgroundColor: lCard,
      selectedColor: lText,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    iconTheme: const IconThemeData(color: lSubtext),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: lText, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(color: lText),
      bodySmall: TextStyle(color: lSubtext),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: blueMain, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: danger, width: 1.5),
      ),
      hintStyle: const TextStyle(color: lSubtext, fontSize: 13, fontWeight: FontWeight.w400),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: blueMain,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: dBg,
    primaryColor: blueMain,
    colorScheme: const ColorScheme.dark(
      primary: blueMain,
      secondary: blueLight,
      surface: dSurface,
      onSurface: dText,
      error: danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: dSurface,
      foregroundColor: dText,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: kToolbarHeight + 12,
      shadowColor: dBorder,
      surfaceTintColor: Colors.transparent,
      shape: Border(
        bottom: BorderSide(color: dBorder, width: 1.5),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: dSurface,
      selectedItemColor: blueMain,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    cardColor: dCard,
    cardTheme: CardThemeData(
      color: dCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerColor: dBorder,
    chipTheme: ChipThemeData(
      backgroundColor: dCard,
      selectedColor: blueMain,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    iconTheme: const IconThemeData(color: dSubtext),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: dText, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(color: dText),
      bodySmall: TextStyle(color: dSubtext),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: blueMain, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: danger, width: 1.5),
      ),
      hintStyle: const TextStyle(color: dSubtext, fontSize: 13, fontWeight: FontWeight.w400),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: blueMain,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // AMBER RIBAPLUS
  // ═══════════════════════════════════════════════════════════════════════════

  static TextTheme _dmSans(TextTheme base) {
    return GoogleFonts.dmSansTextTheme(base);
  }

  static ThemeData amberLight() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );
    final textTheme = _dmSans(base.textTheme).copyWith(
      displayLarge: GoogleFonts.dmSans(
        fontSize: 32, fontWeight: FontWeight.w700, color: alTextPrimary,
      ),
      displayMedium: GoogleFonts.dmSans(
        fontSize: 28, fontWeight: FontWeight.w700, color: alTextPrimary,
      ),
      displaySmall: GoogleFonts.dmSans(
        fontSize: 24, fontWeight: FontWeight.w600, color: alTextPrimary,
      ),
      headlineLarge: GoogleFonts.dmSans(
        fontSize: 22, fontWeight: FontWeight.w600, color: alTextPrimary,
      ),
      headlineMedium: GoogleFonts.dmSans(
        fontSize: 20, fontWeight: FontWeight.w600, color: alTextPrimary,
      ),
      headlineSmall: GoogleFonts.dmSans(
        fontSize: 18, fontWeight: FontWeight.w600, color: alTextPrimary,
      ),
      titleLarge: GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w600, color: alTextPrimary,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w600, color: alTextPrimary,
      ),
      titleSmall: GoogleFonts.dmSans(
        fontSize: 13, fontWeight: FontWeight.w500, color: alTextSecondary,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w400, color: alTextPrimary,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w400, color: alTextPrimary,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w400, color: alTextSecondary,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w600, color: alTextPrimary,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w600, color: alTextPrimary,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 11, fontWeight: FontWeight.w500, color: alTextSecondary,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: alBg,
      primaryColor: amberPrimary,
      colorScheme: const ColorScheme.light(
        primary: contrastAmber, // Use high-contrast amber for light theme
        secondary: amberDark,
        surface: alSurface,
        onSurface: alTextPrimary,
        error: dangerRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: alSurface,
        foregroundColor: alTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: kToolbarHeight + 12,
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(color: alBorder, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: alSurface,
        selectedItemColor: amberPrimaryDark,
        unselectedItemColor: alTextSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      cardColor: alSurface,
      cardTheme: CardThemeData(
        color: alSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerColor: alBorder,
      chipTheme: ChipThemeData(
        backgroundColor: alSurface2,
        selectedColor: amberPrimaryDark,
        labelStyle: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w600, color: alTextPrimary,
        ),
        secondaryLabelStyle: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      iconTheme: const IconThemeData(color: alTextSecondary),
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: alSurface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: amberPrimary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dangerRed, width: 1.5),
        ),
        hintStyle: const TextStyle(color: alTextSecondary, fontSize: 13, fontWeight: FontWeight.w400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: amberPrimary,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: amberPrimary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: amberPrimary,
          side: const BorderSide(color: amberPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: alSurface,
        indicatorColor: amberPrimaryDark.withValues(alpha: 0.15),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: alBorder, thickness: 1),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: amberPrimary,
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData amberDarkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );
    final textTheme = _dmSans(base.textTheme).copyWith(
      displayLarge: GoogleFonts.dmSans(
        fontSize: 32, fontWeight: FontWeight.w700, color: adTextPrimary,
      ),
      displayMedium: GoogleFonts.dmSans(
        fontSize: 28, fontWeight: FontWeight.w700, color: adTextPrimary,
      ),
      displaySmall: GoogleFonts.dmSans(
        fontSize: 24, fontWeight: FontWeight.w600, color: adTextPrimary,
      ),
      headlineLarge: GoogleFonts.dmSans(
        fontSize: 22, fontWeight: FontWeight.w600, color: adTextPrimary,
      ),
      headlineMedium: GoogleFonts.dmSans(
        fontSize: 20, fontWeight: FontWeight.w600, color: adTextPrimary,
      ),
      headlineSmall: GoogleFonts.dmSans(
        fontSize: 18, fontWeight: FontWeight.w600, color: adTextPrimary,
      ),
      titleLarge: GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w600, color: adTextPrimary,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w600, color: adTextPrimary,
      ),
      titleSmall: GoogleFonts.dmSans(
        fontSize: 13, fontWeight: FontWeight.w500, color: adTextSecondary,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w400, color: adTextPrimary,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w400, color: adTextPrimary,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w400, color: adTextSecondary,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w600, color: adTextPrimary,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w600, color: adTextPrimary,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 11, fontWeight: FontWeight.w500, color: adTextSecondary,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: adBg,
      primaryColor: amberPrimary,
      colorScheme: const ColorScheme.dark(
        primary: amberPrimary,
        secondary: amberDark,
        surface: adSurface,
        onSurface: adTextPrimary,
        error: dangerRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: adSurface,
        foregroundColor: adTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: kToolbarHeight + 12,
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(color: adBorder, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: adSurface,
        selectedItemColor: amberPrimary,
        unselectedItemColor: adTextSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      cardColor: adSurface2,
      cardTheme: CardThemeData(
        color: adSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerColor: adBorder,
      chipTheme: ChipThemeData(
        backgroundColor: adSurface2,
        selectedColor: amberPrimary,
        labelStyle: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w600, color: adTextPrimary,
        ),
        secondaryLabelStyle: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      iconTheme: const IconThemeData(color: adTextSecondary),
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: adSurface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: amberPrimary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dangerRed, width: 1.5),
        ),
        hintStyle: const TextStyle(color: adTextSecondary, fontSize: 13, fontWeight: FontWeight.w400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: amberPrimary,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: amberPrimary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: amberPrimary,
          side: const BorderSide(color: amberPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: adSurface,
        indicatorColor: amberPrimary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: adBorder, thickness: 1),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: amberPrimary,
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData purpleLight() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );
    final textTheme = _dmSans(base.textTheme).copyWith(
      displayLarge: GoogleFonts.dmSans(
        fontSize: 32, fontWeight: FontWeight.w700, color: plTextPrimary,
      ),
      displayMedium: GoogleFonts.dmSans(
        fontSize: 28, fontWeight: FontWeight.w700, color: plTextPrimary,
      ),
      displaySmall: GoogleFonts.dmSans(
        fontSize: 24, fontWeight: FontWeight.w600, color: plTextPrimary,
      ),
      headlineLarge: GoogleFonts.dmSans(
        fontSize: 22, fontWeight: FontWeight.w600, color: plTextPrimary,
      ),
      headlineMedium: GoogleFonts.dmSans(
        fontSize: 20, fontWeight: FontWeight.w600, color: plTextPrimary,
      ),
      headlineSmall: GoogleFonts.dmSans(
        fontSize: 18, fontWeight: FontWeight.w600, color: plTextPrimary,
      ),
      titleLarge: GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w600, color: plTextPrimary,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w600, color: plTextPrimary,
      ),
      titleSmall: GoogleFonts.dmSans(
        fontSize: 13, fontWeight: FontWeight.w500, color: plTextSecondary,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w400, color: plTextPrimary,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w400, color: plTextPrimary,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w400, color: plTextSecondary,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w600, color: plTextPrimary,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w600, color: plTextPrimary,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 11, fontWeight: FontWeight.w500, color: plTextSecondary,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: plBg,
      primaryColor: purplePrimary,
      colorScheme: const ColorScheme.light(
        primary: purplePrimary,
        secondary: purpleDark,
        surface: plSurface,
        onSurface: plTextPrimary,
        error: dangerRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: plSurface,
        foregroundColor: plTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: kToolbarHeight + 12,
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(color: plBorder, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: plSurface,
        selectedItemColor: purplePrimaryDark,
        unselectedItemColor: plTextSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      cardColor: plSurface,
      cardTheme: CardThemeData(
        color: plSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerColor: plBorder,
      chipTheme: ChipThemeData(
        backgroundColor: plSurface2,
        selectedColor: purplePrimaryDark,
        labelStyle: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w600, color: plTextPrimary,
        ),
        secondaryLabelStyle: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      iconTheme: const IconThemeData(color: plTextSecondary),
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: plSurface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: purplePrimary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dangerRed, width: 1.5),
        ),
        hintStyle: const TextStyle(color: plTextSecondary, fontSize: 13, fontWeight: FontWeight.w400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: purplePrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: purplePrimary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: purplePrimary,
          side: const BorderSide(color: purplePrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: plSurface,
        indicatorColor: purplePrimaryDark.withValues(alpha: 0.15),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: plBorder, thickness: 1),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: purplePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData purpleDarkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );
    final textTheme = _dmSans(base.textTheme).copyWith(
      displayLarge: GoogleFonts.dmSans(
        fontSize: 32, fontWeight: FontWeight.w700, color: pdTextPrimary,
      ),
      displayMedium: GoogleFonts.dmSans(
        fontSize: 28, fontWeight: FontWeight.w700, color: pdTextPrimary,
      ),
      displaySmall: GoogleFonts.dmSans(
        fontSize: 24, fontWeight: FontWeight.w600, color: pdTextPrimary,
      ),
      headlineLarge: GoogleFonts.dmSans(
        fontSize: 22, fontWeight: FontWeight.w600, color: pdTextPrimary,
      ),
      headlineMedium: GoogleFonts.dmSans(
        fontSize: 20, fontWeight: FontWeight.w600, color: pdTextPrimary,
      ),
      headlineSmall: GoogleFonts.dmSans(
        fontSize: 18, fontWeight: FontWeight.w600, color: pdTextPrimary,
      ),
      titleLarge: GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w600, color: pdTextPrimary,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w600, color: pdTextPrimary,
      ),
      titleSmall: GoogleFonts.dmSans(
        fontSize: 13, fontWeight: FontWeight.w500, color: pdTextSecondary,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w400, color: pdTextPrimary,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w400, color: pdTextPrimary,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w400, color: pdTextSecondary,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w600, color: pdTextPrimary,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w600, color: pdTextPrimary,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 11, fontWeight: FontWeight.w500, color: pdTextSecondary,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: pdBg,
      primaryColor: purplePrimary,
      colorScheme: const ColorScheme.dark(
        primary: purplePrimary,
        secondary: purpleDark,
        surface: pdSurface,
        onSurface: pdTextPrimary,
        error: dangerRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pdSurface,
        foregroundColor: pdTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: kToolbarHeight + 12,
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(color: pdBorder, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: pdSurface,
        selectedItemColor: purplePrimary,
        unselectedItemColor: pdTextSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      cardColor: pdSurface2,
      cardTheme: CardThemeData(
        color: pdSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerColor: pdBorder,
      chipTheme: ChipThemeData(
        backgroundColor: pdSurface2,
        selectedColor: purplePrimary,
        labelStyle: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w600, color: pdTextPrimary,
        ),
        secondaryLabelStyle: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      iconTheme: const IconThemeData(color: pdTextSecondary),
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pdSurface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: purplePrimary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dangerRed, width: 1.5),
        ),
        hintStyle: const TextStyle(color: pdTextSecondary, fontSize: 13, fontWeight: FontWeight.w400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: purplePrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: purplePrimary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: purplePrimary,
          side: const BorderSide(color: purplePrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: pdSurface,
        indicatorColor: purplePrimary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: pdBorder, thickness: 1),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: purplePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GREEN FOREST
  // ═══════════════════════════════════════════════════════════════════════════

  static ThemeData greenLight() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );
    final textTheme = _dmSans(base.textTheme).copyWith(
      displayLarge: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w700, color: glTextPrimary),
      displayMedium: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w700, color: glTextPrimary),
      displaySmall: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w600, color: glTextPrimary),
      headlineLarge: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w600, color: glTextPrimary),
      bodyLarge: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w400, color: glTextPrimary),
      bodyMedium: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w400, color: glTextPrimary),
      bodySmall: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w400, color: glTextSecondary),
    );

    return base.copyWith(
      scaffoldBackgroundColor: glBg,
      primaryColor: greenPrimary,
      colorScheme: const ColorScheme.light(
        primary: greenPrimary,
        secondary: greenDark,
        surface: glSurface,
        onSurface: glTextPrimary,
        error: dangerRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: glSurface,
        foregroundColor: glTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: kToolbarHeight + 12,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: glBorder, width: 1)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: glSurface,
        selectedItemColor: greenPrimaryDark,
        unselectedItemColor: glTextSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      cardColor: glSurface,
      cardTheme: CardThemeData(
        color: glSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerColor: glBorder,
      chipTheme: ChipThemeData(
        backgroundColor: glSurface2,
        selectedColor: greenPrimaryDark,
        labelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: glTextPrimary),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      iconTheme: const IconThemeData(color: glTextSecondary),
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glSurface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: greenPrimary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dangerRed, width: 1.5),
        ),
        hintStyle: const TextStyle(color: glTextSecondary, fontSize: 13, fontWeight: FontWeight.w400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: greenPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }

  static ThemeData greenDarkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );
    final textTheme = _dmSans(base.textTheme).copyWith(
      displayLarge: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w700, color: gdTextPrimary),
      displayMedium: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w700, color: gdTextPrimary),
      displaySmall: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w600, color: gdTextPrimary),
      headlineLarge: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w600, color: gdTextPrimary),
      bodyLarge: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w400, color: gdTextPrimary),
      bodyMedium: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w400, color: gdTextPrimary),
      bodySmall: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w400, color: gdTextSecondary),
    );

    return base.copyWith(
      scaffoldBackgroundColor: gdBg,
      primaryColor: greenPrimary,
      colorScheme: const ColorScheme.dark(
        primary: greenPrimary,
        secondary: greenDark,
        surface: gdSurface,
        onSurface: gdTextPrimary,
        error: dangerRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: gdSurface,
        foregroundColor: gdTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: kToolbarHeight + 12,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: gdBorder, width: 1)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: gdSurface,
        selectedItemColor: greenPrimary,
        unselectedItemColor: gdTextSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      cardColor: gdSurface2,
      cardTheme: CardThemeData(
        color: gdSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerColor: gdBorder,
      chipTheme: ChipThemeData(
        backgroundColor: gdSurface2,
        selectedColor: greenPrimary,
        labelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: gdTextPrimary),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      iconTheme: const IconThemeData(color: gdTextSecondary),
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: gdSurface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: greenPrimary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dangerRed, width: 1.5),
        ),
        hintStyle: const TextStyle(color: gdTextSecondary, fontSize: 13, fontWeight: FontWeight.w400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: greenPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }
}

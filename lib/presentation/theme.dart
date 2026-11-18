import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const blue = Color(0xFF007AFF);
  static const green = Color(0xFF248A3D);
  static const orange = Color(0xFFE8840C);
  static const purple = Color(0xFFAF52DE);
  static const red = Color(0xFFFF3B30);
  static Color recommendation(int? score) => score == null
      ? const Color(0xFF85858D)
      : score >= 8
      ? green
      : score >= 4
      ? orange
      : red;
  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF171719)
      : const Color(0xFFF5F5F7);
  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF242426)
      : Colors.white;
  static Color secondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFAAAAB0)
      : const Color(0xFF77777F);
  static Color score(String grade) => switch (grade) {
    'a' => const Color(0xFF218653),
    'b' => const Color(0xFF669D32),
    'c' => const Color(0xFFC78D00),
    'd' => const Color(0xFFE07623),
    'e' => const Color(0xFFD34B4B),
    _ => const Color(0xFF85858D),
  };
}

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.blue,
    brightness: brightness,
    primary: AppColors.blue,
    surface: dark ? const Color(0xFF242426) : Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF171719)
        : const Color(0xFFF5F5F7),
    fontFamily: 'Arial',
    textTheme: ThemeData(
      brightness: brightness,
    ).textTheme.apply(fontFamily: 'Arial'),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF171719) : const Color(0xFFF5F5F7),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: dark ? const Color(0xFF39393C) : const Color(0xFFECECEF),
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF303033) : const Color(0xFFF0F0F3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 48),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}

import 'package:flutter/material.dart';

/// Bảng màu: Trắng + Xanh dương đậm + Vàng gold.
const Color kNavy = Color(0xFF0D2E6B); // xanh dương đậm
const Color kNavyLight = Color(0xFFE6ECF7);
const Color kGold = Color(0xFFC9A227); // vàng gold
const Color kGoldLight = Color(0xFFFBF3DC);
const Color kBackground = Color(0xFFF5F7FB);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kNavy,
    primary: kNavy,
    secondary: kGold,
    surface: Colors.white,
  );

  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  const btnText = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: kNavy,
      foregroundColor: Colors.white,
      centerTitle: true,
      titleTextStyle:
          TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white),
      iconTheme: IconThemeData(color: Colors.white, size: 28),
      actionsIconTheme: IconThemeData(color: Colors.white, size: 28),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 18),
      bodyMedium: TextStyle(fontSize: 17),
      bodySmall: TextStyle(fontSize: 15),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      labelLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 56),
        textStyle: btnText,
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kNavy,
        minimumSize: const Size(64, 56),
        textStyle: btnText,
        shape: shape,
        side: const BorderSide(color: kNavy, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kNavy,
        minimumSize: const Size(48, 48),
        textStyle: btnText,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kGold,
      foregroundColor: kNavy,
      extendedTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      extendedSizeConstraints: BoxConstraints.tightFor(height: 60),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      labelStyle: const TextStyle(fontSize: 17),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blueGrey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kNavy, width: 2),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? kGold : null),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? kNavy : null),
    ),
  );
}

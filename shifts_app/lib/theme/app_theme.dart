import 'package:flutter/material.dart';

class AppTheme {
  static bool isDaytime(DateTime time) => time.hour >= 6 && time.hour < 18;

  static ThemeData get light => _create(
    brightness: Brightness.light,
    canvas: const Color(0xFFF2F4F7),
    surface: const Color(0xFFFFFFFF),
    surfaceContainer: const Color(0xFFEBEFF3),
    surfaceContainerHighest: const Color(0xFFDCE2E9),
    primary: const Color(0xFF506078),
    onSurface: const Color(0xFF17212D),
    onSurfaceVariant: const Color(0xFF637287),
    outline: const Color(0xFFD4DCE5),
  );

  static ThemeData get dark => _create(
    brightness: Brightness.dark,
    canvas: const Color(0xFF0D1014),
    surface: const Color(0xFF171C22),
    surfaceContainer: const Color(0xFF20262E),
    surfaceContainerHighest: const Color(0xFF2C3540),
    primary: const Color(0xFF526278),
    onSurface: const Color(0xFFF2F4F7),
    onSurfaceVariant: const Color(0xFFA0ACBA),
    outline: const Color(0xFF303944),
  );

  static ThemeData _create({
    required Brightness brightness,
    required Color canvas,
    required Color surface,
    required Color surfaceContainer,
    required Color surfaceContainerHighest,
    required Color primary,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color outline,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      secondary: primary,
      onSecondary: Colors.white,
      tertiary: surfaceContainerHighest,
      onTertiary: onSurface,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainer: surfaceContainer,
      surfaceContainerHighest: surfaceContainerHighest,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w500),
      ),
      dividerColor: outline,
      iconTheme: IconThemeData(color: onSurface),
      listTileTheme: ListTileThemeData(
        textColor: onSurface,
        iconColor: onSurfaceVariant,
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: onSurfaceVariant),
        hintStyle: TextStyle(color: onSurfaceVariant),
        border: OutlineInputBorder(borderSide: BorderSide(color: outline)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStatePropertyAll(surfaceContainerHighest),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    );
  }
}

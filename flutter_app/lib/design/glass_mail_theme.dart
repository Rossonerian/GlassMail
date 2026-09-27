import 'package:flutter/material.dart';

abstract final class GlassMailPalette {
  static const lightBase = Color(0xFFF6F3EF);
  static const lightSurface = Color(0xFFEDE6DE);
  static const lightVariant = Color(0xFFDACEBE);
  static const lightInk = Color(0xFF110E09);
  static const lightMutedInk = Color(0xFF413525);
  static const darkBase = Color(0xFF100D09);
  static const darkSurface = Color(0xFF211A12);
  static const darkVariant = Color(0xFF413525);
  static const darkInk = Color(0xFFF6F3EE);
  static const darkMutedInk = Color(0xFFDCD0BC);
  static const primary = Color(0xFF856B47);
  static const darkPrimary = Color(0xFFA68659);
  static const secondary = Color(0xFF788448);
  static const darkSecondary = Color(0xFF96A45B);

  static const priority = Color(0xFFA68659);
  static const updates = Color(0xFF96A45B);
  static const newsletters = Color(0xFF8EA45B);
  static const personal = Color(0xFFA5B77B);
  static const work = Color(0xFFC0C99C);
  static const promotions = Color(0xFFB69D7C);
  static const reminders = Color(0xFFABB77B);
}

ThemeData glassMailTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: dark ? GlassMailPalette.darkPrimary : GlassMailPalette.primary,
    brightness: brightness,
    surface: dark ? GlassMailPalette.darkBase : GlassMailPalette.lightSurface,
    onSurface: dark ? GlassMailPalette.darkInk : GlassMailPalette.lightInk,
    primary: dark ? GlassMailPalette.darkPrimary : GlassMailPalette.primary,
    secondary: dark
        ? GlassMailPalette.darkSecondary
        : GlassMailPalette.secondary,
    outline: dark ? const Color(0xFF645235) : const Color(0xFFB69D7C),
    outlineVariant: dark ? const Color(0xFF413525) : const Color(0xFFDACEBE),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? GlassMailPalette.darkBase
        : GlassMailPalette.lightBase,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}

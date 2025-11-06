import 'package:flutter/material.dart';

class AppFonts {
  // Font Family
  static const String fontFamily = 'Manrope';

  // Font Weights
  static const FontWeight extraLight = FontWeight.w200;
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;

  // Text Styles
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontWeight: extraBold,
    fontSize: 32,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: bold,
    fontSize: 28,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamily,
    fontWeight: semiBold,
    fontSize: 24,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontWeight: bold,
    fontSize: 22,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: semiBold,
    fontSize: 20,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontWeight: semiBold,
    fontSize: 18,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontWeight: semiBold,
    fontSize: 16,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: medium,
    fontSize: 14,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontWeight: medium,
    fontSize: 12,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontWeight: regular,
    fontSize: 16,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: regular,
    fontSize: 14,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontWeight: light,
    fontSize: 12,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontWeight: medium,
    fontSize: 14,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: medium,
    fontSize: 12,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontWeight: regular,
    fontSize: 10,
  );

  // Custom Text Styles for specific use cases
  static const TextStyle buttonText = TextStyle(
    fontFamily: fontFamily,
    fontWeight: semiBold,
    fontSize: 16,
  );

  static const TextStyle appBarTitle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: semiBold,
    fontSize: 18,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: medium,
    fontSize: 16,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: regular,
    fontSize: 14,
  );

  static const TextStyle inputLabel = TextStyle(
    fontFamily: fontFamily,
    fontWeight: medium,
    fontSize: 14,
  );

  static const TextStyle inputHint = TextStyle(
    fontFamily: fontFamily,
    fontWeight: regular,
    fontSize: 14,
  );

  static const TextStyle errorText = TextStyle(
    fontFamily: fontFamily,
    fontWeight: regular,
    fontSize: 12,
  );

  static const TextStyle successText = TextStyle(
    fontFamily: fontFamily,
    fontWeight: regular,
    fontSize: 12,
  );

  // Helper method to create custom text style
  static TextStyle custom({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? lineHeight,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight ?? regular,
      color: color,
      letterSpacing: letterSpacing,
      height: lineHeight,
      decoration: decoration,
    );
  }
}

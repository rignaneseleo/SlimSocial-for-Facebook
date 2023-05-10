import 'package:flutter/material.dart';

class FacebookColors {
  static const Color official = Color(0xFF3B5998);
  static const Color blue = Color(0xFF355CA8);
  static const Color lightBlue = Color(0xFFD9E2FF);
  static const Color red = Color(0xFFBA1A1A);
  static const Color lightRed = Color(0xFFFFDAD6);
  static const Color darkRed = Color(0xFF8B0000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color lightGrey = Color(0xFFE1E2EC);
  static const Color darkGrey = Color(0xFF44464F);
  static const Color grey = Color(0xFF757780);
  static const Color darkBlue = Color(0xFF080618);
  static const Color lightPurple = Color(0xFFDBE1FF);
  static const Color darkPurple = Color(0xFFC5C6D0);
  static const Color error = Color(0xFFFFB4AB);
  static const Color errorText = Color(0xFF690005);
  static const Color scrim = Color(0xFF000000);
  static const Color surfaceTint = Color(0xFFAFC6FF);
}

final lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: FacebookColors.blue,
  onPrimary: FacebookColors.white,
  primaryContainer: FacebookColors.lightBlue,
  onPrimaryContainer: FacebookColors.darkBlue,
  secondary: FacebookColors.blue,
  onSecondary: FacebookColors.white,
  secondaryContainer: FacebookColors.lightBlue,
  onSecondaryContainer: FacebookColors.darkBlue,
  tertiary: FacebookColors.blue,
  onTertiary: FacebookColors.white,
  tertiaryContainer: FacebookColors.lightBlue,
  onTertiaryContainer: FacebookColors.darkBlue,
  error: FacebookColors.red,
  errorContainer: FacebookColors.lightRed,
  onError: FacebookColors.white,
  onErrorContainer: FacebookColors.darkRed,
  background: FacebookColors.white,
  onBackground: FacebookColors.darkBlue,
  surface: FacebookColors.white,
  onSurface: FacebookColors.darkBlue,
  surfaceVariant: FacebookColors.lightGrey,
  onSurfaceVariant: FacebookColors.darkGrey,
  outline: FacebookColors.grey,
  onInverseSurface: FacebookColors.lightBlue,
  inverseSurface: FacebookColors.darkBlue,
  inversePrimary: FacebookColors.lightBlue,
  shadow: FacebookColors.black,
  surfaceTint: FacebookColors.blue,
  outlineVariant: FacebookColors.darkGrey,
  scrim: FacebookColors.black,
);

final darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: FacebookColors.lightBlue,
  onPrimary: FacebookColors.darkBlue,
  primaryContainer: FacebookColors.darkBlue,
  onPrimaryContainer: FacebookColors.lightBlue,
  secondary: FacebookColors.lightBlue,
  onSecondary: FacebookColors.darkBlue,
  secondaryContainer: FacebookColors.darkBlue,
  onSecondaryContainer: FacebookColors.lightBlue,
  tertiary: FacebookColors.lightBlue,
  onTertiary: FacebookColors.darkBlue,
  tertiaryContainer: FacebookColors.darkBlue,
  onTertiaryContainer: FacebookColors.lightBlue,
  error: FacebookColors.error,
  errorContainer: FacebookColors.darkRed,
  onError: FacebookColors.errorText,
  onErrorContainer: FacebookColors.lightRed,
  background: FacebookColors.darkBlue,
  onBackground: FacebookColors.lightPurple,
  surface: FacebookColors.darkBlue,
  onSurface: FacebookColors.lightPurple,
  surfaceVariant: FacebookColors.darkGrey,
  onSurfaceVariant: FacebookColors.lightPurple,
  outline: FacebookColors.grey,
  onInverseSurface: FacebookColors.darkBlue,
  inverseSurface: FacebookColors.lightPurple,
  inversePrimary: FacebookColors.blue,
  shadow: FacebookColors.black,
  surfaceTint: FacebookColors.lightBlue,
  outlineVariant: FacebookColors.darkGrey,
  scrim: FacebookColors.black,
);

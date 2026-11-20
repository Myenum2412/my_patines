import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_animations.dart';
import 'apple_ui.dart';

/// The app's single [ThemeData]: Hanken Grotesk on a cool paper ground, the
/// logo's blue for actions, hairline-edged surfaces.
ThemeData buildAppTheme() {
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.button),
  );
  const buttonText = TextStyle(
    fontFamily: AppType.family,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: AppType.family,
    // Covers glyphs the brand face does not carry (the rupee sign, for one).
    fontFamilyFallback: const ['Roboto'],
    scaffoldBackgroundColor: AppleColors.canvas,
    colorScheme: const ColorScheme.light(
      primary: AppleColors.brand,
      onPrimary: Colors.white,
      primaryContainer: AppleColors.brandLight,
      onPrimaryContainer: AppleColors.brand,
      secondary: AppleColors.brand,
      surface: Colors.white,
      onSurface: AppleColors.textPrimary,
      onSurfaceVariant: AppleColors.textSecondary,
      outline: AppleColors.border,
      outlineVariant: AppleColors.hairline,
      error: AppleColors.red,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppleColors.brand,
      selectionHandleColor: AppleColors.brand,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppleColors.canvas,
      foregroundColor: AppleColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: AppType.family,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: AppleColors.textPrimary,
      ),
    ),
    dividerColor: AppleColors.hairline,
    dividerTheme: const DividerThemeData(
      color: AppleColors.hairline,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppleColors.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: buttonShape,
        textStyle: buttonText,
        elevation: 0,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppleColors.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: buttonShape,
        textStyle: buttonText,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppleColors.textPrimary,
        minimumSize: const Size(0, 48),
        shape: buttonShape,
        side: const BorderSide(color: AppleColors.border),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppleColors.brand,
        textStyle: buttonText,
      ),
    ),
    // Fields keep the borders their screens draw; the theme only sets the
    // hint colour so nothing doubles up.
    inputDecorationTheme: const InputDecorationTheme(
      hintStyle: TextStyle(color: AppleColors.textTertiary),
    ),
    chipTheme: const ChipThemeData(
      side: BorderSide(color: AppleColors.border),
      shape: StadiumBorder(),
      labelStyle: TextStyle(
        fontFamily: AppType.family,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppleColors.ink,
      contentTextStyle: const TextStyle(
        fontFamily: AppType.family,
        fontSize: 14,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.inner),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppleColors.brand,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeRisePageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

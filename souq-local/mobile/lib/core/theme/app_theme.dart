import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.primaryLight,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
      onSurface: isDark ? Colors.white : AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBackground : AppColors.surfaceLight,
      fontFamily: 'Roboto',
      textTheme: Typography.material2021()
          .black
          .copyWith(
            displaySmall: const TextStyle(
              fontSize: 32,
              height: 1.16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.6,
            ),
            headlineSmall: const TextStyle(
              fontSize: 26,
              height: 1.2,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.35,
            ),
            titleLarge: const TextStyle(
              fontSize: 20,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
            bodyMedium: const TextStyle(fontSize: 14, height: 1.45),
            labelLarge:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          )
          .apply(
            bodyColor: isDark ? Colors.white : AppColors.textPrimary,
            displayColor: isDark ? Colors.white : AppColors.textPrimary,
          ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? AppColors.darkCard : Colors.white,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkBorder : AppColors.border,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.surfaceMuted,
        labelStyle: TextStyle(
            color: isDark ? AppColors.textTertiary : AppColors.textSecondary),
        hintStyle: TextStyle(
            color: isDark ? AppColors.textTertiary : AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.border),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary);
          }
          return TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textTertiary : AppColors.textSecondary);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}

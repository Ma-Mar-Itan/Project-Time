import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'app_colors.dart';

/// Status-color helpers that respect the active brightness and never rely on
/// color alone (status text is always shown alongside).
class StatusColors {
  const StatusColors(this.running, this.paused, this.destructive);

  final Color running;
  final Color paused;
  final Color destructive;

  static StatusColors of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? const StatusColors(
            AppColors.runningDark, AppColors.pausedDark, AppColors.destructiveDark)
        : const StatusColors(
            AppColors.running, AppColors.paused, AppColors.destructive);
  }
}

/// Assembles the Material 3 light and dark themes.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark
        ? const ColorScheme.dark(
            primary: AppColors.darkPrimaryBlue,
            onPrimary: Color(0xFF062E6F),
            secondary: AppColors.darkPrimaryBlue,
            surface: AppColors.darkBackground,
            onSurface: AppColors.darkTextPrimary,
            surfaceContainerLowest: AppColors.darkBackground,
            surfaceContainerLow: AppColors.darkSurface,
            surfaceContainer: AppColors.darkSurface,
            surfaceContainerHigh: AppColors.darkSurfaceRaised,
            surfaceContainerHighest: AppColors.darkSurfaceRaised,
            outline: AppColors.darkBorder,
            outlineVariant: AppColors.darkBorder,
            error: AppColors.destructiveDark,
          )
        : const ColorScheme.light(
            primary: AppColors.primaryBlue,
            onPrimary: Colors.white,
            secondary: AppColors.primaryBlue,
            surface: AppColors.background,
            onSurface: AppColors.textPrimary,
            surfaceContainerLowest: AppColors.background,
            surfaceContainerLow: AppColors.surfaceAlt,
            surfaceContainer: AppColors.surfaceAlt,
            surfaceContainerHigh: Color(0xFFF1F3F4),
            surfaceContainerHighest: Color(0xFFECEEF0),
            outline: AppColors.border,
            outlineVariant: AppColors.borderSubtle,
            error: AppColors.destructive,
          );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      visualDensity: VisualDensity.standard,
    );

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppConstants.cardRadius),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? AppColors.darkSurface : AppColors.background,
        shape: cardShape.copyWith(
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 3,
        height: 72,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.16),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius + 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppConstants.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.cardRadius - 2),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppConstants.minTouchTarget),
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.cardRadius - 2),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius - 2),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius - 2),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 8,
      ),
    );
  }
}

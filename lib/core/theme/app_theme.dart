import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Centralised theming: light, dark and pastel packs, shared shape + type.
class AppTheme {
  AppTheme._();

  static const double cardRadius = 22;
  static const double chipRadius = 14;

  static ThemeData light(ThemePack pack) => _build(Brightness.light, pack);

  static ThemeData dark(ThemePack pack) => _build(Brightness.dark, pack);

  static ThemeData _build(Brightness brightness, ThemePack pack) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: pack.seed,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? pack.seed.withOpacity(0.92) : pack.seed,
    );

    final Color background = isDark ? AppColors.darkBackground : AppColors.warmCream;
    final Color surface = isDark ? AppColors.darkSurface : Colors.white;

    final TextTheme baseText = Typography.material2021().black;
    final TextTheme textTheme = baseText.apply(
      bodyColor: isDark ? AppColors.darkTextMain : AppColors.textMain,
      displayColor: isDark ? AppColors.darkTextMain : AppColors.textMain,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        backgroundColor: background,
        foregroundColor: isDark ? AppColors.darkTextMain : AppColors.textMain,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: isDark ? 0 : 1.5,
        shadowColor: Colors.black.withOpacity(isDark ? 0.4 : 0.10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceAlt : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(chipRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(chipRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(chipRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(chipRadius)),
        side: BorderSide.none,
        backgroundColor: isDark ? AppColors.darkSurfaceAlt : AppColors.warmCream,
        selectedColor: scheme.primary.withOpacity(0.18),
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(chipRadius)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(chipRadius)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(chipRadius)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      dividerTheme: DividerThemeData(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
        thickness: 1,
      ),
    );
  }
}

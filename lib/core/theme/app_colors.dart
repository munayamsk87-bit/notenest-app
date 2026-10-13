import 'package:flutter/material.dart';

/// NoteNest brand palette. Warm, cozy, pastel-forward.
class AppColors {
  AppColors._();

  // Brand base
  static const Color warmCream = Color(0xFFFFF9F1);
  static const Color lavender = Color(0xFFE9DDFB);
  static const Color softPink = Color(0xFFFFE2EA);
  static const Color mintGreen = Color(0xFFDDF5E7);
  static const Color butterYellow = Color(0xFFFFF0BD);
  static const Color skyBlue = Color(0xFFDCEEFF);

  // Accents
  static const Color primaryPurple = Color(0xFF8060C7);
  static const Color textMain = Color(0xFF292638);
  static const Color textMuted = Color(0xFF6E6A7C);

  // Dark theme surfaces
  static const Color darkBackground = Color(0xFF1B1922);
  static const Color darkSurface = Color(0xFF242231);
  static const Color darkSurfaceAlt = Color(0xFF2E2B3C);
  static const Color darkTextMain = Color(0xFFF1EEF7);

  // Luxury accents — champagne & gold, used sparingly for a premium feel
  static const Color pearl = Color(0xFFFFFBF6);
  static const Color champagne = Color(0xFFE7C98A);
  static const Color gold = Color(0xFFC9A227);
  static const Color goldSoft = Color(0xFFF6E7BE);
  static const Color plum = Color(0xFF3A2E52);
  static const Color hairline = Color(0x14000000);
  static const Color goldHairline = Color(0x55C9A227);
}

/// A selectable note card colour. `default` follows the active theme surface.
class NoteColorOption {
  final String id;
  final int value;
  final Color light;
  final Color dark;
  const NoteColorOption(this.id, this.value, this.light, this.dark);
}

class NoteColors {
  NoteColors._();

  static const List<NoteColorOption> all = <NoteColorOption>[
    NoteColorOption('default', 0, Color(0xFFFFFFFF), Color(0xFF242231)),
    NoteColorOption('cream', 1, AppColors.warmCream, Color(0xFF2A2620)),
    NoteColorOption('lavender', 2, AppColors.lavender, Color(0xFF2A2438)),
    NoteColorOption('pink', 3, AppColors.softPink, Color(0xFF33222A)),
    NoteColorOption('mint', 4, AppColors.mintGreen, Color(0xFF1F2E27)),
    NoteColorOption('butter', 5, AppColors.butterYellow, Color(0xFF322C1B)),
    NoteColorOption('sky', 6, AppColors.skyBlue, Color(0xFF1F2833)),
  ];

  static NoteColorOption byValue(int value) {
    return all.firstWhere(
      (NoteColorOption o) => o.value == value,
      orElse: () => all.first,
    );
  }

  static Color resolve(int value, Brightness brightness) {
    final NoteColorOption option = byValue(value);
    return brightness == Brightness.dark ? option.dark : option.light;
  }
}

/// Pastel theme packs (Spec §2 "Optional pastel theme packs").
enum ThemePack { classic, lavender, mint, rose, sky, champagne }

extension ThemePackX on ThemePack {
  String get label {
    switch (this) {
      case ThemePack.classic:
        return 'Classic';
      case ThemePack.lavender:
        return 'Lavender';
      case ThemePack.mint:
        return 'Mint';
      case ThemePack.rose:
        return 'Rose';
      case ThemePack.sky:
        return 'Sky';
      case ThemePack.champagne:
        return 'Champagne';
    }
  }

  Color get seed {
    switch (this) {
      case ThemePack.classic:
        return AppColors.primaryPurple;
      case ThemePack.lavender:
        return const Color(0xFF9B7FE0);
      case ThemePack.mint:
        return const Color(0xFF4FB286);
      case ThemePack.rose:
        return const Color(0xFFE0709A);
      case ThemePack.sky:
        return const Color(0xFF5B9BD5);
      case ThemePack.champagne:
        return AppColors.gold;
    }
  }
}

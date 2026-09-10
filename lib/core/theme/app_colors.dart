import 'package:flutter/material.dart';

/// Centralized App Colors — single source of truth for brand palette.
/// Previously duplicated as `brandGold: 0xFFF4C025` in 10+ screens and
/// `_diaryGold: 0xfff4b400` / `_footprintGold` — now unified.
///
/// Behavior is identical: old constants are kept as aliases where needed
/// so no visual change.
class AppColors {
  const AppColors._();

  /// Primary brand gold — used for BottomNavigation active, buttons, highlights
  /// Original: `brandGold = 0xFFF4C025` (home, profile, main_navigation, etc.)
  static const Color brandGold = Color(0xFFF4C025);

  /// Deeper gold for diary/footprint/maps — original `_diaryGold/_footprintGold = 0xFFF4B400`
  static const Color diaryGold = Color(0xFFF4B400);
  static const Color footprintGold = Color(0xFFF4B400);

  /// Pale gold backgrounds — `_diaryPaleGold = 0xFFFFEFBD`, `lightGold = 0xFFFFD54F`
  static const Color diaryPaleGold = Color(0xFFFFEFBD);
  static const Color lightGold = Color(0xFFFFD54F);

  /// Neutral borders / canvases — duplicated across diary/footprint/plan
  static const Color diaryBorder = Color(0xFFE6E6E6);
  static const Color footprintCanvas = Color(0xFFF8F9FA);
  static const Color footprintCardBorder = Color(0xFFEADFCA);
  static const Color planCanvas = Color(0xFFF7F2E8);
  static const Color ink = Color(0xFF292620);

  /// Semantic overlays — `withValues(alpha:)` helpers keep call-sites unchanged
  static Color brandGoldWith(double alpha) => brandGold.withValues(alpha: alpha);
  static Color diaryGoldWith(double alpha) => diaryGold.withValues(alpha: alpha);
}

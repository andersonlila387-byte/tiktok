import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFFF5F5F5);
  static const card = Colors.white;

  /// Top bar: the same light grey as the page (the "TikTok Studio" pill on it
  /// is white).
  static const topBar = background;
  static const border = Color(0xFFE3E3E3);
  static const divider = Color(0xFFEDEDED);
  static const text = Color(0xFF000000);
  static const muted = Color(0xFF757575);
  static const faint = Color(0xFFB4B5B9);
  static const accent = Color(0xFF0A72D8);
  static const accentMid = Color(0xFF7DB9EF);
  static const accentLight = Color(0xFFD4E6F9);
  static const accentTint = Color(0xFFE5F1FC);
  static const selectedTile = Color(0xFFF5FAFD);
  static const selectedTileBorder = Color(0xFF78B2E6);
  static const statIcon = Color(0xFF999999);
  static const statNumber = Color(0xFF2B2B2B);
  static const tabDivider = Color(0xFFE0E0E0);
  static const line = Color(0xFF1B78D4);
  static const grid = Color(0xFFDADADA);
  static const chip = Color(0xFFEBEBEB);
  static const chipText = Color(0xFF787A7F);
  static const track = Color(0xFFE4E4E4);
  static const up = Color(0xFF19A974);
  static const neutralDelta = Color(0xFF9A9BA0);
  static const brand = Color(0xFFFE2C55);
  static const down = Color(0xFFD64545);
}

/// Whether text uses Roboto, the font of the TikTok Studio app on Android
/// (downloaded on first use). Tests switch this
/// off so they never touch the network.
bool useBrandFont = true;

/// Text style in the app font. Use this instead of a bare [TextStyle] so the
/// right weight of the font is picked.
TextStyle t(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.text,
  double? height,
  double? spacing,
}) {
  if (!useBrandFont) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: spacing,
    );
  }
  return GoogleFonts.roboto(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: spacing,
  );
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      surface: AppColors.card,
    ),
    scaffoldBackgroundColor: AppColors.background,
  );
  final text = base.textTheme.apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: AppColors.divider,
    textTheme: useBrandFont
        ? text.apply(fontFamily: GoogleFonts.roboto().fontFamily)
        : text,
  );
}

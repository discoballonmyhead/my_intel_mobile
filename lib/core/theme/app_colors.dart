import 'package:flutter/material.dart';

/// Design tokens carried over from `index.css`.
///
/// Two named palettes: GHOST (light) and VOID (dark). Anything the Material
/// [ColorScheme] cannot express — surface2, the second accent, verified and
/// warn — is exposed through [AppPalette], a ThemeExtension, so widgets read
/// it with `Theme.of(context).extension<AppPalette>()!` and never hard-code a
/// hex value.
class AppColors {
  const AppColors._();

  // ── LIGHT — GHOST ──
  static const Color lightBg = Color(0xFFF8F7F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF0EDE8);
  static const Color lightBorder = Color(0xFFE0DBD4);
  static const Color lightAccent = Color(0xFFC0404A);
  static const Color lightAccent2 = Color(0xFF8A3A8A);
  static const Color lightVerified = Color(0xFF2A7A4A);
  static const Color lightWarn = Color(0xFFB06020);
  static const Color lightText = Color(0xFF1A1614);
  static const Color lightMuted = Color(0xFF7A6A60);

  // ── DARK — VOID ──
  static const Color darkBg = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF0A0A0A);
  static const Color darkSurface2 = Color(0xFF111111);
  static const Color darkBorder = Color(0xFF1E1E1E);
  static const Color darkAccent = Color(0xFFC0404A);
  static const Color darkAccent2 = Color(0xFFE84848);
  static const Color darkVerified = Color(0xFF30D880);
  static const Color darkWarn = Color(0xFFE8A020);
  static const Color darkText = Color(0xFFE0E8F0);
  static const Color darkMuted = Color(0xFF5A6880);

  /// Region marker colours used by the map / region list.
  static const Color regionBreaking = Color(0xFFFF6B35);
  static const Color regionBusy = Color(0xFFFFCC00);
  static const Color regionQuiet = Color(0xFF00D4FF);
}

/// Extra palette slots that Material's ColorScheme has no home for.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.surface2,
    required this.border,
    required this.accent,
    required this.accent2,
    required this.verified,
    required this.warn,
    required this.muted,
    required this.activeBg,
    required this.postHover,
  });

  final Color surface2;
  final Color border;
  final Color accent;
  final Color accent2;
  final Color verified;
  final Color warn;
  final Color muted;
  final Color activeBg;
  final Color postHover;

  static const AppPalette light = AppPalette(
    surface2: AppColors.lightSurface2,
    border: AppColors.lightBorder,
    accent: AppColors.lightAccent,
    accent2: AppColors.lightAccent2,
    verified: AppColors.lightVerified,
    warn: AppColors.lightWarn,
    muted: AppColors.lightMuted,
    activeBg: Color(0x0FC0404A),
    postHover: Color(0x05000000),
  );

  static const AppPalette dark = AppPalette(
    surface2: AppColors.darkSurface2,
    border: AppColors.darkBorder,
    accent: AppColors.darkAccent,
    accent2: AppColors.darkAccent2,
    verified: AppColors.darkVerified,
    warn: AppColors.darkWarn,
    muted: AppColors.darkMuted,
    activeBg: Color(0x0FC0404A),
    postHover: Color(0x05FFFFFF),
  );

  @override
  AppPalette copyWith({
    Color? surface2,
    Color? border,
    Color? accent,
    Color? accent2,
    Color? verified,
    Color? warn,
    Color? muted,
    Color? activeBg,
    Color? postHover,
  }) {
    return AppPalette(
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      accent2: accent2 ?? this.accent2,
      verified: verified ?? this.verified,
      warn: warn ?? this.warn,
      muted: muted ?? this.muted,
      activeBg: activeBg ?? this.activeBg,
      postHover: postHover ?? this.postHover,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      surface2: Color.lerp(surface2, other.surface2, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accent2: Color.lerp(accent2, other.accent2, t)!,
      verified: Color.lerp(verified, other.verified, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      activeBg: Color.lerp(activeBg, other.activeBg, t)!,
      postHover: Color.lerp(postHover, other.postHover, t)!,
    );
  }
}

/// Convenience accessor so widgets can write `context.palette.accent`.
extension PaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}

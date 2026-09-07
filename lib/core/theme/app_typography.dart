import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Inter for prose, JetBrains Mono for labels, tags, counters and timestamps —
/// the same pairing the web client uses.
class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(Color text, Color muted) {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(color: text, fontWeight: FontWeight.w600),
      headlineLarge: base.headlineLarge?.copyWith(color: text, fontWeight: FontWeight.w600, height: 1.2),
      headlineMedium: base.headlineMedium?.copyWith(color: text, fontWeight: FontWeight.w600, height: 1.25),
      headlineSmall: base.headlineSmall?.copyWith(color: text, fontWeight: FontWeight.w600, height: 1.3),
      titleLarge: base.titleLarge?.copyWith(color: text, fontWeight: FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(color: text, fontWeight: FontWeight.w500),
      titleSmall: base.titleSmall?.copyWith(color: text, fontWeight: FontWeight.w500),
      bodyLarge: base.bodyLarge?.copyWith(color: text, height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(color: text, height: 1.5),
      bodySmall: base.bodySmall?.copyWith(color: muted, height: 1.4),
      labelLarge: base.labelLarge?.copyWith(color: text, fontWeight: FontWeight.w500),
      labelMedium: base.labelMedium?.copyWith(color: muted),
      labelSmall: base.labelSmall?.copyWith(color: muted),
    );
  }

  /// Monospace style for tags, roles, counters and nav labels.
  static TextStyle mono({
    double size = 11,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double letterSpacing = 0.5,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}

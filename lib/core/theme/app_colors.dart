import 'package:flutter/material.dart';

class AppColors {
  // ─── Primary (Earthy Deep Green) ───────────────────────────────────
  static const Color primary = Color(0xFF1B5E20); 
  static const Color primaryLight = Color(0xFF4C8C4A);
  static const Color primaryDark = Color(0xFF003300);

  // ─── Secondary (Growth & Water Blue) ────────────────────────────────
  static const Color secondary = Color(0xFF0277BD);
  static const Color secondaryLight = Color(0xFF58A5F0);
  static const Color secondaryDark = Color(0xFF004C8C);

  // ─── Accent (Golden Harvest / Sun) ──────────────────────────────────
  static const Color accent = Color(0xFFFBC02D);
  static const Color accentLight = Color(0xFFFFF263);
  static const Color accentDark = Color(0xFFC49000);

  // ─── Background & Surface (Premium Neutrals) ────────────────────────
  static const Color background = Color(0xFFF7FBF7); // Softest Mint
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  
  // Glassmorphic / Overlay Colors
  static Color glassWhite = Colors.white.withOpacity(0.7);
  static Color glassBlack = Colors.black.withOpacity(0.05);

  // ─── Functional ────────────────────────────────────────────────────
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFFFA000);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF1976D2);

  // ─── Text ──────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1C19); // Near Black
  static const Color textSecondary = Color(0xFF5D625D); // Muted Grey
  static const Color textMuted = Color(0xFF8D938D); // Deeper Muted

  // ─── Shadows & Borders ─────────────────────────────────────────────
  static const Color border = Color(0xFFE1E5E1);
  static Color cardShadow = const Color(0xFF000000).withOpacity(0.06);
}

extension ColorCompat on Color {
  double get r => red / 255.0;
  double get g => green / 255.0;
  double get b => blue / 255.0;
  double get a => alpha / 255.0;

  Color withValues({
    double? alpha,
    double? red,
    double? green,
    double? blue,
  }) {
    int toChannel(double value) => value.round().clamp(0, 255).toInt();

    return Color.fromARGB(
      alpha == null ? this.alpha : toChannel(alpha * 255),
      red == null ? this.red : toChannel(red * 255),
      green == null ? this.green : toChannel(green * 255),
      blue == null ? this.blue : toChannel(blue * 255),
    );
  }
}

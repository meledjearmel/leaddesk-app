import 'package:flutter/material.dart';

/// Palette de l'interface : sombre et chaleureuse, seul thème du bureau
/// (voir `docs/decisions.md`, D-007).
abstract final class LdColors {
  /// Fond de la fenêtre.
  static const Color background = Color(0xFF121212);

  /// Surface des panneaux et des cartes.
  static const Color surface = Color(0xFF1E1E1E);

  /// Surface surélevée : bulles, champs, pastilles.
  static const Color surfaceHigh = Color(0xFF2A2927);

  /// Teinte des surfaces en verre posées sur la scène.
  static const Color glass = Color(0xC71B1A19);

  static const Color border = Color(0x17FFFFFF);
  static const Color borderStrong = Color(0x2BFFFFFF);
  static const Color hover = Color(0x0FFFFFFF);
  static const Color selected = Color(0x14FFFFFF);

  static const Color text = Color(0xFFF5F3EF);
  static const Color textMuted = Color(0xFF99948D);
  static const Color textFaint = Color(0xFF6E6A64);

  /// Accent ambre : sélection, onglet actif, agent en conversation.
  static const Color amber = Color(0xFFF2B34C);

  /// Vert terminal : travail en cours.
  static const Color green = Color(0xFF4ADE80);
  static const Color greenSoft = Color(0x244ADE80);
}

/// Rayons d'angle partagés.
abstract final class LdRadius {
  static const double panel = 18;
  static const double card = 14;
  static const double control = 10;
}

ThemeData buildLeadDeskTheme() {
  const scheme = ColorScheme.dark(
    primary: LdColors.amber,
    onPrimary: Color(0xFF1A1407),
    surface: LdColors.surface,
    onSurface: LdColors.text,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: LdColors.background,
    // Windows est la seule cible de la V1.
    fontFamily: 'Segoe UI',
    splashFactory: NoSplash.splashFactory,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: LdColors.amber,
      selectionColor: Color(0x55F2B34C),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2D2B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: LdColors.border),
      ),
      textStyle: const TextStyle(color: LdColors.text, fontSize: 12),
    ),
  );
}

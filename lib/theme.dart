import 'package:flutter/material.dart';

/// Couleurs du Labo d'Émile, avec les mêmes noms de rôles que Réviser.
/// Les valeurs sont celles déjà utilisées dans les écrans (bleu vif, etc.).
class LaboColors extends ThemeExtension<LaboColors> {
  const LaboColors({
    required this.paper,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.encre,
    required this.rouge,
    required this.line,
    required this.good,
    required this.warn,
    required this.nuit,
    required this.or,
  });

  final Color paper;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color encre;
  final Color rouge;
  final Color line;
  final Color good;
  final Color warn;

  /// Bleu nuit de l'écran d'accueil et de la barre du haut.
  final Color nuit;

  /// Jaune des diamants et des récompenses.
  final Color or;

  static const light = LaboColors(
    paper: LaboPalette.paper,
    surface: LaboPalette.surface,
    ink: LaboPalette.ink,
    muted: LaboPalette.muted,
    encre: LaboPalette.encre,
    rouge: LaboPalette.rouge,
    line: LaboPalette.line,
    good: LaboPalette.good,
    warn: LaboPalette.warn,
    nuit: LaboPalette.nuit,
    or: LaboPalette.or,
  );

  static LaboColors of(BuildContext context) =>
      Theme.of(context).extension<LaboColors>()!;

  @override
  LaboColors copyWith() => this;

  @override
  LaboColors lerp(LaboColors? other, double t) => t < 0.5 ? this : (other ?? this);
}

/// Valeurs constantes de la palette (utilisables dans les widgets const).
class LaboPalette {
  static const paper = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const ink = Color(0xFF2C3E50);
  static const muted = Colors.blueGrey;
  static const encre = Colors.blue;
  static const rouge = Colors.red;
  static const line = Color(0xFFE2E8F0);
  static const good = Colors.green;
  static const warn = Colors.orange;
  static const nuit = Color(0xFF1A237E);
  static const or = Colors.amber;

  /// Doré des petites touches d'icône (même jaune que Cartable).
  static const touche = Color(0xFFFFC43D);
}

/// Formes communes avec Réviser : cartes ~12 px, boutons ~8 px.
class LaboShape {
  static const double cardRadius = 12;
  static const double buttonRadius = 8;
  static final BorderRadius card = BorderRadius.circular(cardRadius);
  static final BorderRadius button = BorderRadius.circular(buttonRadius);
}

/// Espacements (multiples de 4).
class LaboSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

ThemeData buildTheme(LaboColors colors) {
  final scheme = ColorScheme.fromSeed(
    seedColor: colors.encre,
    brightness: Brightness.light,
  ).copyWith(
    primary: colors.encre,
    onPrimary: Colors.white,
    surface: colors.surface,
    onSurface: colors.ink,
    outline: colors.line,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: Brightness.light,
    extensions: [colors],
    cardTheme: CardThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: Colors.black26,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: LaboShape.card),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: LaboShape.card),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

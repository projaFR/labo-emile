import 'package:flutter/material.dart';

import '../theme.dart';

/// Microscope dessiné en code (aucune police, aucun téléchargement).
///
/// Même langage que les icônes de Cartable (cartable) et de Réviser (livre) :
/// - uniquement des aplats pleins aux coins bien arrondis, aucun trait fin ;
/// - deux tons : le blanc (léger dégradé froid vers le bas) devant, et une
///   version translucide du blanc pour la pièce « de derrière » (le bras),
///   comme la poignée de Cartable ou la couverture de Réviser ;
/// - une seule touche dorée, petite et en façade : la lamelle posée sur la
///   platine (comme les fermoirs de Cartable ou le marque-page de Réviser) ;
/// - une ombre portée très douce sous les pièces blanches (icône de Réviser).
///
/// Grille de 100 × 100, silhouette dans ~70 % du carré : lisible de 24 à 160 px.
///
/// [grandIcone] bascule vers une seconde silhouette, plus grande et plus
/// carrée (pour occuper ~64 % du carré 1024 comme le livre de Réviser, zone
/// sûre Android comprise), utilisée uniquement pour fabriquer l'icône de
/// l'appli (`tool/generer_icone_test.dart`). Par défaut (`false`), le dessin
/// est strictement identique à l'ancien : l'écran de lancement et les petits
/// usages dans l'appli ne changent pas.
class MicroscopeIcon extends StatelessWidget {
  const MicroscopeIcon({
    super.key,
    this.size = 64,
    this.color = Colors.white,
    this.accent = LaboPalette.touche,
    this.bras,
    this.grandIcone = false,
  });

  final double size;
  final Color color;
  final Color accent;

  /// Couleur pleine du bras (sinon : blanc translucide, qui prend le fond).
  final Color? bras;

  /// Variante agrandie/recentrée réservée à la fabrication de l'icône.
  final bool grandIcone;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _MicroscopePainter(color, accent, bras, grandIcone),
      );
}

class _MicroscopePainter extends CustomPainter {
  _MicroscopePainter(this.color, this.accent, this.bras, this.grandIcone);

  final Color color;
  final Color accent;
  final Color? bras;
  final bool grandIcone;

  /// Inclinaison du tube (vers la gauche, bras à droite).
  static const double _tilt = -0.38;

  /// Pointe de l'objectif : centre de rotation du tube.
  static const Offset _pivot = Offset(44, 57);

  /// Inclinaison plus douce pour la variante icône (silhouette plus large,
  /// moins raide).
  static const double _tiltIcone = -0.30;
  static const Offset _pivotIcone = Offset(45, 56);

  static RRect _r(double x, double y, double w, double h, double rad) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rad));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100);
    if (grandIcone) {
      _paintIcone(canvas);
    } else {
      _paintClassique(canvas);
    }
    canvas.restore();
  }

  /// Dessin d'origine, inchangé : utilisé partout dans l'appli (écran de
  /// lancement, onglet « Aujourd'hui »...).
  void _paintClassique(Canvas canvas) {
    // Blanc avec un dégradé froid à peine visible (comme Cartable et Réviser).
    final front = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, Color.lerp(color, const Color(0xFFDDE2FF), 0.35)!],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
    // Ton de derrière : le blanc rendu translucide, il prend la teinte du fond.
    final back = Paint()
      ..isAntiAlias = true
      ..color = bras ?? color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final shadow = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFF0A1A4A).withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);

    // 1. Bras (derrière) : arc épais de la tête du tube jusqu'au pied.
    canvas.drawPath(
      Path()
        ..moveTo(46, 32)
        ..cubicTo(84, 26, 90, 66, 64, 84),
      back,
    );

    // 2. Pièces blanches, avec leur ombre douce dessinée juste avant.
    void solid(void Function(Paint p) draw) {
      canvas.save();
      canvas.translate(0, 1.6);
      draw(shadow);
      canvas.restore();
      draw(front);
    }

    // Tube incliné : oculaire, corps, objectif, plus la molette qui fait le
    // raccord avec le bras.
    solid((p) {
      canvas.save();
      canvas.translate(_pivot.dx, _pivot.dy);
      canvas.rotate(_tilt);
      canvas.translate(-_pivot.dx, -_pivot.dy);
      canvas.drawRRect(_r(36.5, 7, 15, 10, 3.5), p); // oculaire
      canvas.drawRRect(_r(32, 15, 24, 31, 8), p); // corps
      canvas.drawRRect(_r(38, 44, 12, 13, 3.5), p); // objectif
      canvas.restore();
    });
    solid((p) => canvas.drawCircle(const Offset(47.5, 31.5), 6.5, p)); // molette

    // Platine (touche le bras) et pied.
    solid((p) => canvas.drawRRect(_r(22, 67, 52, 8, 4), p));
    solid((p) => canvas.drawRRect(_r(18, 82, 64, 10, 5), p));

    // 3. Unique touche dorée : la lamelle sur la platine, en léger dégradé
    //    (comme le marque-page de Réviser).
    final gold = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accent, Color.lerp(accent, const Color(0xFFE8921A), 0.35)!],
      ).createShader(const Rect.fromLTWH(0, 60, 100, 8));
    canvas.drawRRect(_r(30, 60.5, 28, 7, 3), gold);
  }

  /// Variante « icône » : silhouette plus grande et plus carrée (largeur et
  /// hauteur comparables, comme le livre de Réviser), pièces élargies et
  /// coins plus arrondis pour plus de poids visuel et moins de raideur, bras
  /// toujours translucide (effet verre dépoli) mais plus visible, et petit
  /// reflet près de la lamelle dorée.
  void _paintIcone(Canvas canvas) {
    const dx = -1.2, dy = -3.0; // recentrage mesuré sur le rendu 1024 px.
    canvas.translate(dx, dy);

    final front = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, Color.lerp(color, const Color(0xFFDDE2FF), 0.35)!],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
    // Bras : reste translucide (verre dépoli), mais un peu moins pâle et
    // plus épais pour bien se lire même à 48 px.
    final back = Paint()
      ..isAntiAlias = true
      ..color = bras ?? color.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    // Fin liseré clair le long du bord extérieur du bras : une touche de
    // lumière qui le détache du fond sans le rendre opaque ni uniforme.
    final brasEclat = Paint()
      ..isAntiAlias = true
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final shadow = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFF0A1A4A).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);

    final brasPath = Path()
      ..moveTo(49, 28)
      ..cubicTo(96, 23, 99, 61, 66, 81);

    // Grande ombre d'assise sous tout l'appareil (comme le socle du livre
    // de Réviser) : donne du poids et ancre le dessin.
    canvas.save();
    canvas.translate(0, 2.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(9, 80, 82, 16),
        const Radius.circular(8),
      ),
      Paint()
        ..isAntiAlias = true
        ..color = const Color(0xFF0A1A4A).withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6),
    );
    canvas.restore();

    // 1. Bras (derrière), puis son liseré clair décalé vers l'intérieur de
    //    la courbe (le côté « éclairé »).
    canvas.drawPath(brasPath, back);
    canvas.save();
    canvas.translate(-2.2, -1.6);
    canvas.drawPath(brasPath, brasEclat);
    canvas.restore();

    // 2. Pièces blanches, avec leur ombre douce dessinée juste avant.
    void solid(void Function(Paint p) draw) {
      canvas.save();
      canvas.translate(0, 2.0);
      draw(shadow);
      canvas.restore();
      draw(front);
    }

    // Tube incliné (un peu moins que l'original, silhouette plus ronde) :
    // oculaire, corps, objectif, plus la molette qui fait le raccord.
    solid((p) {
      canvas.save();
      canvas.translate(_pivotIcone.dx, _pivotIcone.dy);
      canvas.rotate(_tiltIcone);
      canvas.translate(-_pivotIcone.dx, -_pivotIcone.dy);
      canvas.drawRRect(_r(34, 5, 20, 11, 5.5), p); // oculaire
      canvas.drawRRect(_r(29, 14, 30, 27, 11), p); // corps
      canvas.drawRRect(_r(35, 38, 18, 15, 5.5), p); // objectif
      canvas.restore();
    });
    solid((p) => canvas.drawCircle(const Offset(50, 29), 8, p)); // molette

    // Platine (touche le bras) et pied, élargis pour plus de solidité.
    solid((p) => canvas.drawRRect(_r(16, 61, 66, 11, 5.5), p));
    solid((p) => canvas.drawRRect(_r(10, 77, 80, 15, 7.5), p));

    // 3. Unique touche dorée : la lamelle sur la platine, en léger dégradé.
    final gold = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accent, Color.lerp(accent, const Color(0xFFE8921A), 0.35)!],
      ).createShader(const Rect.fromLTWH(0, 57, 100, 9));
    canvas.drawRRect(_r(23, 57.5, 34, 9, 4.5), gold);

    // Petit reflet discret dans le coin de la lamelle, un peu plus présent
    // qu'une simple esquisse : une étincelle à 4 branches (pas une croix
    // pleine), sans visage ni personnage.
    final etincelle = Paint()
      ..isAntiAlias = true
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    const centreEtincelle = Offset(49, 60);
    canvas.drawLine(
      centreEtincelle.translate(-2.3, 0),
      centreEtincelle.translate(2.3, 0),
      etincelle,
    );
    canvas.drawLine(
      centreEtincelle.translate(0, -1.7),
      centreEtincelle.translate(0, 1.7),
      etincelle,
    );
    canvas.drawCircle(centreEtincelle, 1, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_MicroscopePainter old) =>
      old.color != color ||
      old.accent != accent ||
      old.bras != bras ||
      old.grandIcone != grandIcone;
}

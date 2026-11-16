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
class MicroscopeIcon extends StatelessWidget {
  const MicroscopeIcon({
    super.key,
    this.size = 64,
    this.color = Colors.white,
    this.accent = LaboPalette.touche,
    this.bras,
  });

  final double size;
  final Color color;
  final Color accent;

  /// Couleur pleine du bras (sinon : blanc translucide, qui prend le fond).
  final Color? bras;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _MicroscopePainter(color, accent, bras),
      );
}

class _MicroscopePainter extends CustomPainter {
  _MicroscopePainter(this.color, this.accent, this.bras);

  final Color color;
  final Color accent;
  final Color? bras;

  /// Inclinaison du tube (vers la gauche, bras à droite).
  static const double _tilt = -0.38;

  /// Pointe de l'objectif : centre de rotation du tube.
  static const Offset _pivot = Offset(44, 57);

  static RRect _r(double x, double y, double w, double h, double rad) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rad));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100);

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

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MicroscopePainter old) =>
      old.color != color || old.accent != accent || old.bras != bras;
}


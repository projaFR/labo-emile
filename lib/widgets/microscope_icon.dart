import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Microscope dessiné en code (aucune police, aucun téléchargement).
/// Formes pleines et arrondies, blanches, avec une seule touche d'or :
/// la lamelle posée sur la platine. Même esprit que les icônes de Cartable.
class MicroscopeIcon extends StatelessWidget {
  const MicroscopeIcon({
    super.key,
    this.size = 64,
    this.color = Colors.white,
    this.accent = LaboPalette.touche,
  });

  final double size;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _MicroscopePainter(color, accent),
      );
}

class _MicroscopePainter extends CustomPainter {
  _MicroscopePainter(this.color, this.accent);

  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.scale(s);
    final white = Paint()..color = color..isAntiAlias = true;
    final gold = Paint()..color = accent..isAntiAlias = true;
    RRect r(double x, double y, double w, double h, double rad) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rad));

    // Bras en arc, à droite, de la tête du tube jusqu'au pied.
    final arm = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawPath(
      Path()
        ..moveTo(52, 34)
        ..cubicTo(82, 30, 86, 66, 62, 86),
      arm,
    );

    // Tube incliné : oculaire, corps, objectif.
    canvas.save();
    canvas.translate(45, 62);
    canvas.rotate(-math.pi / 13);
    canvas.translate(-45, -62);
    canvas.drawRRect(r(37, 6, 16, 10, 4), white);
    canvas.drawRRect(r(34, 15, 22, 33, 6), white);
    canvas.drawRRect(r(39.5, 47, 11, 14, 3), white);
    canvas.restore();

    // Platine, lamelle dorée, pied.
    canvas.drawRRect(r(22, 70, 44, 7, 3.5), white);
    canvas.drawRRect(r(36, 64.5, 18, 6, 3), gold);
    canvas.drawRRect(r(18, 84, 64, 9, 4.5), white);
  }

  @override
  bool shouldRepaint(_MicroscopePainter old) =>
      old.color != color || old.accent != accent;
}

// Génère les icônes de l'appli en peignant le widget MicroscopeIcon.
// Lancer : flutter test tool/generer_icone_test.dart
// (hors du dossier test/, donc ignoré par un simple `flutter test`).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/theme.dart';
import 'package:myapp/widgets/microscope_icon.dart';

const _degrade = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    LaboPalette.nuit,
    Color(0xFF283593),
    Color(0xFF1565C0),
    Color(0xFF0D47A1),
  ],
);

void main() {
  final cle = GlobalKey();

  Future<void> rendre(
    WidgetTester tester,
    String chemin,
    int px, {
    required bool fond,
    required double part, // taille du widget relative au carré
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(px.toDouble(), px.toDouble());
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: cle,
          child: Container(
            width: px.toDouble(),
            height: px.toDouble(),
            decoration: fond ? const BoxDecoration(gradient: _degrade) : null,
            alignment: Alignment.center,
            child: MicroscopeIcon(size: px * part),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final RenderRepaintBoundary b =
          cle.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image img = await b.toImage(pixelRatio: 1);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File(chemin)..createSync(recursive: true);
      f.writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  testWidgets('génère les icônes', (tester) async {
    addTearDown(tester.view.reset);
    // Le dessin occupe ~70 % de son carré.
    await rendre(tester, 'assets/icon.png', 1024, fond: true, part: 1.0);
    // Zone sûre adaptative Android : 66 % (0,70 x 0,93 = 65 %).
    await rendre(tester, 'assets/icon_foreground.png', 1024,
        fond: false, part: 0.93);
    for (final t in [192, 512]) {
      await rendre(tester, 'web/icons/Icon-$t.png', t, fond: true, part: 1.0);
      // Maskable : contenu dans 80 % (0,70 x 1,0 = 70 %).
      await rendre(tester, 'web/icons/Icon-maskable-$t.png', t,
          fond: true, part: 1.0);
    }
    await rendre(tester, 'web/favicon.png', 48, fond: true, part: 1.1);
    for (final t in [512, 192, 48]) {
      await rendre(tester, 'captures/_apercu_$t.png', t, fond: true, part: 1.0);
    }
  });
}

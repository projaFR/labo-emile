// Peint le widget MicroscopeIcon seul (fond transparent) en 1024 px.
// Lancer : flutter test tool/generer_icone_test.dart
// Puis : python tool/generer_icones.py (fond, masque, tailles, .ico).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/widgets/microscope_icon.dart';

void main() {
  final cle = GlobalKey();

  testWidgets('peint le dessin', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 1024);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: cle,
          child: const SizedBox(
            width: 1024,
            height: 1024,
            child: Center(child: MicroscopeIcon(size: 720, grandIcone: true)),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final RenderRepaintBoundary b =
          cle.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image img = await b.toImage(pixelRatio: 1);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      File('captures/_dessin.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}

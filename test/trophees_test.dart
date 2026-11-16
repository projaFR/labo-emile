import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/logic/trophees_logic.dart';
import 'package:myapp/theme.dart';
import 'package:myapp/views/trophees_view.dart';

void main() {
  group('galerieTitres', () {
    test('niveau 1 : premier titre actuel, les 9 autres verrouillés', () {
      final g = galerieTitres(1);
      expect(g.length, 10);
      expect(g.first.etat, EtatTitre.actuel);
      expect(g.first.nom, 'Œuf Mystérieux');
      expect(g.first.emoji, '🥚');
      expect(g.skip(1).every((t) => t.etat == EtatTitre.verrouille), isTrue);
      expect(g[1].niveauMin, 11);
    });

    test('niveau 25 : deux titres débloqués puis actuel puis verrouillés', () {
      final g = galerieTitres(25);
      expect(g[0].etat, EtatTitre.debloque);
      expect(g[1].etat, EtatTitre.debloque);
      expect(g[2].etat, EtatTitre.actuel);
      expect(g[3].etat, EtatTitre.verrouille);
    });

    test('niveau 10 et 11 : changement de titre à la frontière', () {
      expect(galerieTitres(10)[0].etat, EtatTitre.actuel);
      expect(galerieTitres(11)[0].etat, EtatTitre.debloque);
      expect(galerieTitres(11)[1].etat, EtatTitre.actuel);
    });

    test('niveau 100 : le dernier titre est actuel, aucun verrouillé', () {
      final g = galerieTitres(100);
      expect(g.last.etat, EtatTitre.actuel);
      expect(g.last.niveauMax, 100);
      expect(g.any((t) => t.etat == EtatTitre.verrouille), isFalse);
    });
  });

  test('calculerStats compte étoiles et leçons parfaites', () {
    final s = calculerStats(
      diamants: 40,
      combo: 3,
      etoilesParLecon: const [
        [true, true, true],
        [true, false, false],
        [false, false, false],
      ],
    );
    expect(s.etoilesGagnees, 4);
    expect(s.etoilesTotal, 9);
    expect(s.leconsParfaites, 1);
    expect(s.leconsTotal, 3);
    expect(s.diamants, 40);
    expect(s.combo, 3);
  });

  testWidgets('page Trophées au niveau 1', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(LaboColors.light),
        home: Scaffold(
          body: TropheesView(
            stats: calculerStats(
              diamants: 0,
              combo: 0,
              etoilesParLecon: const [
                [false, false, false],
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mes trophées'), findsOneWidget);
    expect(find.text('Œuf Mystérieux'), findsWidgets);
    expect(find.text('Niveau 1'), findsWidgets);
    expect(find.text('Mon coin collection'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('leçons à 3 étoiles'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('0/1'), findsOneWidget);
    expect(find.text('Titre mystère'), findsWidgets);
  });
}

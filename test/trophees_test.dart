import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/logic/accueil_logic.dart';
import 'package:myapp/logic/trophees_logic.dart';
import 'package:myapp/models/lesson_model.dart';
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

  group('badges de succès des leçons', () {
    test('separerBadgeSucces avec emoji, sans emoji et absent', () {
      final avec = separerBadgeSucces('🦉 Dompteur de Hiboux', 'Pluriel');
      expect(avec.emoji, '🦉');
      expect(avec.nom, 'Dompteur de Hiboux');

      final sansEmoji = separerBadgeSucces('As du Calcul', 'Calcul');
      expect(sansEmoji.emoji, '🏅');
      expect(sansEmoji.nom, 'As du Calcul');

      final vide = separerBadgeSucces(null, 'Les Fractions');
      expect(vide.emoji, '🏅');
      expect(vide.nom, 'Champion · Les Fractions');
    });

    test('badgePourLecon se débloque uniquement à 3 étoiles', () {
      const ref = LeconRef(
        'Français',
        LessonModel(
          titre: 'Pluriel en -OU',
          succes: '🦉 Dompteur de Hiboux',
          astuces: [],
          exercices: [],
          quiz: [],
        ),
      );
      final b2 = badgePourLecon(ref, [true, true, false]);
      expect(b2.debloque, isFalse);
      expect(b2.etoiles, 2);

      final b3 = badgePourLecon(ref, [true, true, true]);
      expect(b3.debloque, isTrue);
      expect(b3.etoiles, 3);
      expect(b3.emoji, '🦉');
      expect(b3.nom, 'Dompteur de Hiboux');
    });

    testWidgets('affiche la grille des badges dans TropheesView', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(LaboColors.light),
          home: Scaffold(
            body: TropheesView(
              stats: calculerStats(
                diamants: 15,
                combo: 0,
                etoilesParLecon: const [
                  [true, true, true],
                  [true, false, false],
                ],
              ),
              badgesLecons: const [
                BadgeLecon(
                  titreLecon: 'Pluriel en -OU',
                  matiere: 'Français',
                  emoji: '🦉',
                  nom: 'Dompteur de Hiboux',
                  debloque: true,
                  etoiles: 3,
                ),
                BadgeLecon(
                  titreLecon: 'Multiplications',
                  matiere: 'Mathématiques',
                  emoji: '🧮',
                  nom: 'Architecte des Nombres',
                  debloque: false,
                  etoiles: 1,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mes badges de leçons'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('Dompteur de Hiboux'), findsOneWidget);
      expect(find.text('Architecte des Nombres'), findsOneWidget);
      expect(find.text('⭐⭐⭐ Débloqué !'), findsOneWidget);
      expect(find.text('⭐ 1/3'), findsOneWidget);
    });
  });
}

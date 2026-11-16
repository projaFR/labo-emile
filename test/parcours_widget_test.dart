import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/models/lesson_model.dart';
import 'package:myapp/theme.dart';
import 'package:myapp/views/parcours_screen.dart';

void main() {
  testWidgets('parcours : étape, puis récap, puis quitter avec confirmation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const lecon = LessonModel(
      titre: 'Ma leçon',
      astuces: [FlashcardModel(question: 'Capitale ?', reponse: 'Paris')],
      exercices: [],
      quiz: [],
    );
    final diamants = ValueNotifier<int>(0);
    final confetti = ConfettiController(duration: const Duration(seconds: 1));
    var retourAccueil = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(LaboColors.light),
        home: ParcoursScreen(
          lesson: lecon,
          etapes: const [0],
          depart: 0,
          complet: true,
          confetti: confetti,
          etoiles: () => [false, false, false],
          diamants: diamants,
          onDiamondEarned: () {},
          onEtoile: (_) {},
          onSuccess: (_) {},
          onFailure: () {},
          onRetourAccueil: () => retourAccueil++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Étape 1 sur 1 · Astuces'), findsOneWidget);

    // Retour en cours de route : confirmation.
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Quitter la leçon ?'), findsOneWidget);
    await tester.tap(find.text('Continuer la leçon'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('VOIR LA SOLUTION'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('MAÎTRISÉ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Leçon terminée'), findsWidgets);
    // Le bouton répond tout de suite, pendant l'animation des étoiles.
    await tester.tap(find.text("Retour à Aujourd'hui"));
    expect(retourAccueil, 1);
    await tester.pumpAndSettle();
    expect(find.text("Retour à Aujourd'hui"), findsOneWidget);
    expect(find.text('Rejouer'), findsOneWidget);
    expect(find.textContaining('du 1er coup'), findsOneWidget);
  });
}

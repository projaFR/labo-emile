import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/logic/parcours_logic.dart';
import 'package:myapp/theme.dart';
import 'package:myapp/views/fin_lecon_view.dart';

void main() {
  testWidgets('fin de leçon : les boutons répondent dès le premier affichage', (
    tester,
  ) async {
    var retours = 0;
    var rejouer = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(LaboColors.light),
        home: Scaffold(
          body: FinLeconView(
            leconComplete: true,
            nomEtape: 'Astuces',
            etoiles: 3,
            etoilesMax: 3,
            diamants: 5,
            recap: cumuler(const <ResultatEtape>[]),
            message: 'Bravo',
            libelleRetour: "Retour à Aujourd'hui",
            onRetour: () => retours++,
            onRejouer: () => rejouer++,
          ),
        ),
      ),
    );
    // Aucune attente : l'animation des étoiles commence à peine.
    await tester.tap(find.text("Retour à Aujourd'hui"));
    expect(retours, 1);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Rejouer'));
    expect(rejouer, 1);
    await tester.pumpAndSettle();
  });
}

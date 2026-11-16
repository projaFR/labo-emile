import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/lesson_model.dart';
import 'package:myapp/theme.dart';
import 'package:myapp/views/exercise_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('exercice à 2 trous : taper 10 dans le 1er champ reste possible', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const lecon = LessonModel(
      titre: 'Multiplications',
      astuces: [],
      exercices: [
        ExerciseModel(
          question: '14 x 4 = ([?] x 4) + ([?] x 4)',
          consigne: 'Décompose 14 :',
          reponsesMultiples: ['10', '4'],
          astuceErreur: '14 = 10 + 4.',
        ),
      ],
      quiz: [],
    );

    var succes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(LaboColors.light),
        home: Scaffold(
          body: ExerciseView(
            lesson: lecon,
            onSuccess: () => succes++,
            onFailure: () {},
            onPerfectScore: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final champs = find.byType(TextField);
    expect(champs, findsNWidgets(2));

    await tester.enterText(champs.at(0), '10');
    await tester.enterText(champs.at(1), '4');
    await tester.tap(find.text('🚀 VALIDER MA RÉPONSE'));
    await tester.pumpAndSettle();

    expect(succes, 1);
    expect(find.text('Bravo ! 🎉'), findsOneWidget);
  });
}

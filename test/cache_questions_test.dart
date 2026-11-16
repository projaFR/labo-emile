import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:myapp/data/database.dart';
import 'package:myapp/logic/memoire.dart';
import 'package:myapp/theme.dart';
import 'package:myapp/views/home_screen.dart';

void main() {
  test('les empreintes d\'une leçon ne sont calculées qu\'une fois', () {
    final l = InitialDatabase.data.values.first.first;
    final a = questionsDeLecon(l);
    final avant = compteurCalculsQuestions;
    for (var i = 0; i < 50; i++) {
      expect(identical(questionsDeLecon(l), a), isTrue);
    }
    expect(compteurCalculsQuestions, avant);
  });

  testWidgets('reconstruire l\'accueil ne recalcule pas les empreintes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(LaboColors.light), home: const HomeScreen()),
    );
    await tester.pumpAndSettle();
    final avant = compteurCalculsQuestions;
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Leçons'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Aujourd'hui"));
      await tester.pumpAndSettle();
    }
    expect(compteurCalculsQuestions, avant);
  });
}

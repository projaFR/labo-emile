import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/theme.dart';
import 'package:myapp/views/home_screen.dart';

void main() {
  testWidgets('accueil : leçon du soir, navigation à 3 entrées', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(LaboColors.light), home: const HomeScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Leçon du soir'), findsNothing); // texte précédé d'un emoji
    expect(find.textContaining('Leçon du soir'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.textContaining('Rien à revoir'), findsOneWidget);

    await tester.tap(find.text('Leçons'));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter une leçon'), findsOneWidget);
    expect(find.text('Toutes'), findsOneWidget);

    await tester.tap(find.text('Trophées'));
    await tester.pumpAndSettle();
    expect(find.text('Mes trophées'), findsOneWidget);
  });
}

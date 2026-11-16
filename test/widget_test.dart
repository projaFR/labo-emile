import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/main.dart';

void main() {
  testWidgets('Test de chargement initial', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    // Instancie l'application de base
    await tester.pumpWidget(const MyApp());

    // Vérifie simplement que le moteur démarre
    expect(find.byType(MyApp), findsOneWidget);

    // Laisse l'écran de lancement finir son animation (≈ 3 s) pour qu'aucun
    // minuteur ne reste en attente à la fin du test.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  });
}

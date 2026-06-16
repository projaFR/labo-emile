import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';

void main() {
  testWidgets('Test de chargement initial', (WidgetTester tester) async {
    // Instancie l'application de base
    await tester.pumpWidget(const MyApp());

    // Vérifie simplement que le moteur démarre
    expect(find.byType(MyApp), findsOneWidget);
  });
}

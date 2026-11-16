import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/views/revision_view.dart';

void main() {
  testWidgets('révision vide : message encourageant', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RevisionView(questions: const [], onTerminee: () async => 0),
      ),
    );
    expect(find.textContaining('Rien à revoir'), findsOneWidget);
  });
}

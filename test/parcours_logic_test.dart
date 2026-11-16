import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/logic/parcours_logic.dart';
import 'package:myapp/models/lesson_model.dart';

LessonModel lecon({int a = 1, int e = 1, int q = 1}) => LessonModel(
  titre: 'T',
  astuces: List.generate(a, (i) => FlashcardModel(question: 'q$i', reponse: 'r')),
  exercices: List.generate(
    e,
    (i) => ExerciseModel(
      question: 'x',
      consigne: 'c',
      reponseAttendue: '1',
      astuceErreur: '',
    ),
  ),
  quiz: List.generate(
    q,
    (i) => QuizModel(question: 'z', options: ['a', 'b'], indexCorrect: 0),
  ),
);

void main() {
  test('départ : première étape non faite, sinon début', () {
    expect(departParcours([0, 1, 2], [false, false, false]), 0);
    expect(departParcours([0, 1, 2], [true, false, false]), 1);
    expect(departParcours([0, 1, 2], [true, true, false]), 2);
    expect(departParcours([0, 1, 2], [true, true, true]), 0);
    expect(departParcours([0, 2], [true, false, false]), 1);
  });

  test('étape suivante et libellé', () {
    expect(etapeSuivante(0, 3), 1);
    expect(etapeSuivante(2, 3), isNull);
    expect(libelleEtape(1, 3, 1), 'Étape 2 sur 3 · Entraînement');
    expect(progressionParcours(1, 3), closeTo(1 / 3, 1e-9));
    expect(progressionParcours(0, 0), 0);
  });

  test('étapes disponibles ignorent les parties vides', () {
    expect(etapesDisponibles(lecon()), [0, 1, 2]);
    expect(etapesDisponibles(lecon(a: 0, q: 0)), [1]);
  });

  test('cumul du récap : somme, étapes passées ignorées, pas de doublon', () {
    final r = cumuler([
      const ResultatEtape(premierCoup: 4, deuxiemeEssai: 1, rates: 1, diamants: 6, aRetravailler: ['a']),
      const ResultatEtape.passee(),
      const ResultatEtape(premierCoup: 2, rates: 2, diamants: 3, aRetravailler: ['a', 'b']),
    ]);
    expect(r.premierCoup, 6);
    expect(r.deuxiemeEssai, 1);
    expect(r.rates, 3);
    expect(r.diamants, 9);
    expect(r.aRetravailler, ['a', 'b']);
  });

  test('étoiles du récap : anciennes + gagnées', () {
    expect(
      etoilesRecap([true, false, false], {
        1: const ResultatEtape(etoile: true),
        2: const ResultatEtape(),
      }),
      2,
    );
    expect(etoilesRecap([false, false, false], {}), 0);
  });

  test('texte court et messages', () {
    expect(texteCourt('2 + [?] = 5'), '2 + … = 5');
    expect(texteCourt('a' * 100).length, 60);
    for (var s = 0; s < 3; s++) {
      for (var e = 0; e <= 3; e++) {
        final m = messageEncouragement(e, graine: s);
        expect('!'.allMatches(m).length, lessThan(2));
      }
    }
    expect(messageEncouragement(3, graine: 0), isNot(messageEncouragement(3, graine: 1)));
  });
}

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/logic/seance_logic.dart';
import 'package:myapp/models/lesson_model.dart';

void main() {
  group('2e essai', () {
    test('juste au 1er essai', () {
      expect(resoudreEssai(estJuste: true, essai: 1), ResultatEssai.juste);
    });
    test('faux au 1er essai : on réessaie', () {
      expect(resoudreEssai(estJuste: false, essai: 1), ResultatEssai.reessayer);
    });
    test('juste au 2e essai', () {
      expect(resoudreEssai(estJuste: true, essai: 2), ResultatEssai.juste);
    });
    test('faux au 2e essai : on montre la réponse', () {
      expect(
        resoudreEssai(estJuste: false, essai: 2),
        ResultatEssai.montrerReponse,
      );
    });
  });

  group('bonne réponse affichée', () {
    test('nombre simple', () {
      const ex = ExerciseModel(
        question: '3 + [?] = 10',
        consigne: 'c',
        reponseAttendue: ' 7 ',
        astuceErreur: 'a',
      );
      expect(texteBonneReponse(ex), '7');
    });
    test('plusieurs trous', () {
      const ex = ExerciseModel(
        question: '[?] + [?]',
        consigne: 'c',
        reponsesMultiples: ['3', '4'],
        astuceErreur: 'a',
      );
      expect(texteBonneReponse(ex), '3 ; 4');
    });
  });

  group('étoile des exercices', () {
    test('tout juste (au besoin au 2e essai) = étoile', () {
      expect(etoileExercices(0), isTrue);
    });
    test('une réponse montrée = pas d\'étoile', () {
      expect(etoileExercices(1), isFalse);
    });
  });

  group('combo', () {
    test('une erreur fait redescendre d\'un cran', () {
      expect(comboApresErreur(7), 6);
      expect(comboApresErreur(1), 0);
    });
    test('jamais sous zéro', () {
      expect(comboApresErreur(0), 0);
    });
  });

  group('tirage de la séance', () {
    test('leçon de 25 : 10 exercices, dans l\'ordre de la leçon', () {
      final t = tirerSeance(25, {}, rng: Random(1));
      expect(t.indices.length, 10);
      expect(t.indices.toSet().length, 10);
      final tri = [...t.indices]..sort();
      expect(t.indices, tri);
    });
    test('pas de répétition tant qu\'il en reste', () {
      final rng = Random(2);
      final t1 = tirerSeance(25, {}, rng: rng);
      final t2 = tirerSeance(25, t1.vusApres, rng: rng);
      expect(t2.indices.toSet().intersection(t1.indices.toSet()), isEmpty);
      // 5 restants à la 3e séance : ils sont tous pris, complétés par des vus.
      final t3 = tirerSeance(25, t2.vusApres, rng: rng);
      final restants = List.generate(25, (i) => i)
          .where((i) => !t2.vusApres.contains(i))
          .toSet();
      expect(t3.indices.length, 10);
      expect(t3.indices.toSet().containsAll(restants), isTrue);
      // Nouveau tour ensuite : on repart sans tout compter comme vu.
      expect(t3.vusApres.length, 5);
    });
    test('leçon de 6 : tout est proposé', () {
      final t = tirerSeance(6, {}, rng: Random(3));
      expect(t.indices, [0, 1, 2, 3, 4, 5]);
    });
    test('tout vu : nouveau tour', () {
      final t = tirerSeance(
        25,
        Set<int>.from(List.generate(25, (i) => i)),
        rng: Random(4),
      );
      expect(t.indices.length, 10);
      expect(t.vusApres.length, 10);
    });
    test('leçon vide', () {
      expect(tirerSeance(0, {}).indices, isEmpty);
    });
  });

  group('Défi Chrono', () {
    test('le temps écoulé n\'est pas une faute', () {
      final m = MancheQuiz(30);
      m.tempsEcoule();
      expect(m.erreurs, 0);
      expect(m.manquees, 1);
      expect(m.bonnes, 0);
    });
    test('bonus de rapidité seulement avec un chrono', () {
      expect(MancheQuiz(30).repondreJuste(25), 2);
      expect(MancheQuiz(30).repondreJuste(10), 1);
      expect(MancheQuiz(15).repondreJuste(11), 2);
      expect(MancheQuiz(0).repondreJuste(0), 1);
    });
    test('étoile : tout juste, sans temps écoulé', () {
      final m = MancheQuiz(30)..repondreJuste(20);
      expect(m.etoile(1), isTrue);
      final n = MancheQuiz(30)
        ..repondreJuste(20)
        ..tempsEcoule();
      expect(n.etoile(2), isFalse);
    });
  });
}

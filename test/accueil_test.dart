import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/logic/accueil_logic.dart';
import 'package:myapp/logic/memoire.dart';
import 'package:myapp/models/lesson_model.dart';

LessonModel _lecon(String titre, [List<String> questions = const []]) =>
    LessonModel(
      titre: titre,
      astuces: [for (final q in questions) FlashcardModel(question: q, reponse: 'r')],
      exercices: const [],
      quiz: const [],
    );

void main() {
  final base = {
    'Maths': [_lecon('Base1'), _lecon('Base2')],
    'Français': [_lecon('Base3')],
  };
  final titresBase = {'Base1', 'Base2', 'Base3'};

  group('leçon du soir', () {
    test('aucune leçon : null', () {
      expect(choisirLeconDuSoir([], {}), isNull);
    });
    test('aucune importée : la première de base', () {
      final r = choisirLeconDuSoir(aplatir(base), titresBase);
      expect(r!.lecon.titre, 'Base1');
    });
    test('importées sans repère : la dernière de la liste', () {
      final b = {
        'Maths': [_lecon('Base1'), _lecon('A'), _lecon('B')],
        'Histoire': [_lecon('C')],
      };
      final r = choisirLeconDuSoir(aplatir(b), {'Base1'});
      expect(r!.lecon.titre, 'C');
      expect(r.matiere, 'Histoire');
    });
    test('dernière importée connue : elle gagne', () {
      final b = {
        'Maths': [_lecon('Base1'), _lecon('A'), _lecon('B')],
        'Histoire': [_lecon('C')],
      };
      final r = choisirLeconDuSoir(aplatir(b), {'Base1'}, derniereImportee: 'A');
      expect(r!.lecon.titre, 'A');
    });
    test('dernière importée disparue : retour à la liste', () {
      final b = {'Maths': [_lecon('Base1'), _lecon('A')]};
      final r = choisirLeconDuSoir(aplatir(b), {'Base1'}, derniereImportee: 'Z');
      expect(r!.lecon.titre, 'A');
    });
  });

  group('étapes', () {
    test('première étape non faite', () {
      expect(premiereEtapeNonFaite([false, false, false]), 0);
      expect(premiereEtapeNonFaite([true, false, false]), 1);
      expect(premiereEtapeNonFaite([true, false, true]), 1);
      expect(premiereEtapeNonFaite([true, true, false]), 2);
      expect(premiereEtapeNonFaite([true, true, true]), -1);
    });
    test('nombre d\'étapes faites', () {
      expect(nombreEtapesFaites([true, false, true]), 2);
      expect(nombreEtapesFaites([false, false, false]), 0);
    });
  });

  test('filtre par matière', () {
    final toutes = aplatir(base);
    expect(filtrerParMatiere(toutes, null).length, 3);
    expect(filtrerParMatiere(toutes, 'Maths').map((r) => r.lecon.titre), ['Base1', 'Base2']);
    expect(filtrerParMatiere(toutes, 'Inconnue'), isEmpty);
  });

  group('à revoir', () {
    late DateTime now;
    setUp(() => now = DateTime(2026, 11, 16, 9));

    test('nombre à revoir par leçon', () {
      final m = Memoire(horloge: () => now);
      final l1 = _lecon('L1', ['a', 'b']);
      final l2 = _lecon('L2', ['c']);
      for (final r in [...questionsDeLecon(l1), ...questionsDeLecon(l2)]) {
        m.enregistrer(r.cle, Resultat.rate);
      }
      now = DateTime(2026, 11, 17, 9); // demain : tout est dû
      expect(nbARevoirLecon(m, l1), 2);
      expect(nbARevoirLecon(m, l2), 1);
      expect(nbARevoirLecon(m, _lecon('L3', ['z'])), 0);
    });

    test('plusFaibles : questions suivies seulement, boîte basse d\'abord, sans toucher à la mémoire', () {
      final m = Memoire(horloge: () => now);
      final l = _lecon('L', ['a', 'b', 'c']);
      final refs = questionsDeLecon(l);
      m.enregistrer(refs[0].cle, Resultat.premierCoup); // boîte 1
      m.enregistrer(refs[1].cle, Resultat.rate); // boîte 1
      // refs[2] jamais vue
      final avant = m.toJsonString();
      final f = m.plusFaibles(refs);
      expect(f.length, 2);
      expect(f.any((r) => r.cle == refs[2].cle), isFalse);
      expect(m.toJsonString(), avant);
      expect(m.plusFaibles(refs, max: 1).length, 1);
    });
  });

  group('niveaux', () {
    test('niveau 1 à zéro diamant, titre et badge', () {
      expect(niveauPour(0), 1);
      expect(badgePour(0), 'Nv.1 - 🥚 Œuf Mystérieux');
      expect(niveauPour(seuilNiveau(11)), 11);
      expect(titreRangPour(11), '🐣 Poussin Curieux');
    });
    test('progression entre 0 et 1', () {
      expect(progressionNiveau(0), 0);
      expect(progressionNiveau(8), 0); // pile au niveau 2
      expect(progressionNiveau(10), inExclusiveRange(0, 1));
    });
  });
}

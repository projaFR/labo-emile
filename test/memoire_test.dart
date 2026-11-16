import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/logic/memoire.dart';
import 'package:myapp/models/lesson_model.dart';
import 'package:myapp/services/memoire_service.dart';

void main() {
  late DateTime maintenant;
  Memoire neuve() => Memoire(horloge: () => maintenant);
  void avancer(int jours) =>
      maintenant = DateTime(maintenant.year, maintenant.month, maintenant.day + jours, 10);

  setUp(() => maintenant = DateTime(2026, 11, 16, 9));

  LessonModel lecon(String titre, List<String> cartes, List<String> exos,
          List<String> quiz) =>
      LessonModel(
        titre: titre,
        astuces: [for (final c in cartes) FlashcardModel(question: c, reponse: 'r')],
        exercices: [
          for (final e in exos)
            ExerciseModel(question: e, consigne: 'c', reponseAttendue: '1', astuceErreur: 'a')
        ],
        quiz: [
          for (final q in quiz)
            QuizModel(question: q, options: const ['a', 'b'], indexCorrect: 0)
        ],
      );

  group('boites et intervalles', () {
    test('1 - 2 - 4 - 8 - 16 jours quand tout est juste du premier coup', () {
      final m = neuve();
      final attendu = [1, 2, 4, 8, 16, 16];
      for (var i = 0; i < attendu.length; i++) {
        m.enregistrer('k', Resultat.premierCoup);
        final e = m.etat('k')!;
        expect(e.boite, (i + 1).clamp(1, 5));
        expect(e.retour, ajouterJours(maintenant, attendu[i]));
        avancer(attendu[i]); // le jour du retour
        expect(m.estDue('k'), isTrue);
      }
    });

    test('juste au 2e essai : boite inchangee, retour demain', () {
      final m = neuve();
      m.enregistrer('k', Resultat.premierCoup);
      avancer(1);
      m.enregistrer('k', Resultat.premierCoup); // boite 2
      avancer(2);
      m.enregistrer('k', Resultat.deuxiemeEssai);
      expect(m.etat('k')!.boite, 2);
      expect(m.etat('k')!.retour, ajouterJours(maintenant, 1));
    });

    test('faux deux fois : retour boite 1, retour demain', () {
      final m = neuve();
      for (var i = 0; i < 3; i++) {
        m.enregistrer('k', Resultat.premierCoup);
        avancer(16);
      }
      m.enregistrer('k', Resultat.rate);
      expect(m.etat('k')!.boite, 1);
      expect(m.etat('k')!.retour, ajouterJours(maintenant, 1));
      expect(m.etat('k')!.ratees, 1);
    });

    test('question nouvelle ratee : boite 1, demain', () {
      final m = neuve()..enregistrer('k', Resultat.rate);
      expect(m.etat('k')!.boite, 1);
      expect(m.estDue('k'), isFalse);
      avancer(1);
      expect(m.estDue('k'), isTrue);
    });

    test('rejouer le meme jour ne fait pas monter la boite', () {
      final m = neuve();
      m.enregistrer('k', Resultat.premierCoup);
      m.enregistrer('k', Resultat.premierCoup);
      m.enregistrer('k', Resultat.premierCoup);
      expect(m.etat('k')!.boite, 1);
    });

    test('une erreur sur une question programmee plus tard la ramene', () {
      final m = neuve();
      for (var i = 0; i < 3; i++) {
        m.enregistrer('k', Resultat.premierCoup);
        avancer(16);
      }
      m.enregistrer('k', Resultat.premierCoup); // boite 4, retour +8
      m.enregistrer('k', Resultat.rate);
      expect(m.etat('k')!.boite, 1);
      expect(m.etat('k')!.retour, ajouterJours(maintenant, 1));
    });

    test('passage a minuit : le jour local fait foi', () {
      maintenant = DateTime(2026, 12, 31, 23, 50);
      final m = neuve()..enregistrer('k', Resultat.rate);
      expect(m.etat('k')!.retour, '2027-01-01');
      maintenant = DateTime(2027, 1, 1, 0, 5);
      expect(m.estDue('k'), isTrue);
    });
  });

  group('dues, tri, maitrise', () {
    test('dues triees : plus en retard d abord, limitees a 12', () {
      final l = lecon('L', List.generate(20, (i) => 'c$i'), [], []);
      final refs = questionsDeLecon(l);
      final m = neuve();
      // c0 rate il y a 5 jours, c1 il y a 2 jours, le reste hier.
      maintenant = DateTime(2026, 11, 10, 10);
      m.enregistrer(refs[0].cle, Resultat.rate);
      maintenant = DateTime(2026, 11, 13, 10);
      m.enregistrer(refs[1].cle, Resultat.rate);
      maintenant = DateTime(2026, 11, 15, 10);
      for (var i = 2; i < 20; i++) {
        m.enregistrer(refs[i].cle, Resultat.rate);
      }
      maintenant = DateTime(2026, 11, 16, 9);
      final dues = m.dues(refs);
      expect(dues.length, 12);
      expect(dues[0].cle, refs[0].cle);
      expect(dues[1].cle, refs[1].cle);
      expect(m.nombreDues(refs), 20);
    });

    test('rien de du quand rien n a ete repondu', () {
      final refs = questionsDeLecon(lecon('L', ['a'], ['b'], ['c']));
      expect(neuve().dues(refs), isEmpty);
    });

    test('maitrise = part des questions en boite >= 3', () {
      final refs = questionsDeLecon(lecon('L', ['a', 'b'], [], []));
      final m = neuve();
      expect(m.maitrise(refs), 0);
      for (var i = 0; i < 3; i++) {
        m.enregistrer(refs[0].cle, Resultat.premierCoup);
        avancer(16);
      }
      expect(m.maitrise(refs), 0.5);
      expect(m.nombreSuiviesParmi(refs), 1);
    });
  });

  group('empreinte', () {
    test('stable et connue', () {
      expect(empreinte('abc'), empreinte('abc'));
      expect(empreinte('abc').length, 16);
      expect(empreinte(''), '811c9dc501234567');
    });

    test('distincte selon titre, type et texte', () {
      final a = cleQuestion('L', TypeQuestion.astuce, '2+2');
      expect(a, isNot(cleQuestion('M', TypeQuestion.astuce, '2+2')));
      expect(a, isNot(cleQuestion('L', TypeQuestion.exercice, '2+2')));
      expect(a, isNot(cleQuestion('L', TypeQuestion.astuce, '2+3')));
      expect(a, cleQuestion('L', TypeQuestion.astuce, '2+2'));
    });

    test('leçon réimportée : mémoire retrouvée ; question modifiée : à zéro', () {
      final m = neuve();
      final v1 = questionsDeLecon(lecon('L', ['a'], ['b'], ['c']));
      for (final r in v1) {
        m.enregistrer(r.cle, Resultat.premierCoup);
      }
      final v2 = questionsDeLecon(lecon('L', ['a'], ['b modifiée'], ['c']));
      expect(m.etat(v2[0].cle), isNotNull);
      expect(m.etat(v2[1].cle), isNull);
      expect(m.etat(v2[2].cle), isNotNull);
    });
  });

  group('JSON et stockage', () {
    test('aller-retour', () {
      final m = neuve()..enregistrer('k', Resultat.premierCoup);
      final l = Memoire.lire(m.toJsonString(), horloge: () => maintenant);
      expect(l.corrompue, isFalse);
      expect(l.memoire.etat('k')!.boite, 1);
    });

    test('absent : vide sans alerte', () {
      final l = Memoire.lire(null);
      expect(l.corrompue, isFalse);
      expect(l.memoire.nombreSuivies, 0);
    });

    test('corrompu : signalé', () {
      for (final mauvais in [
        '{pas du json',
        '[1,2]',
        '{"version":2,"questions":{}}',
        '{"version":1,"questions":{"k":{"b":9,"d":"2026-01-01"}}}',
        '{"version":1,"questions":{"k":{"b":1,"d":"demain"}}}',
      ]) {
        final l = Memoire.lire(mauvais);
        expect(l.corrompue, isTrue, reason: mauvais);
        expect(l.memoire.nombreSuivies, 0);
      }
    });

    test('reinitialiser vide la mémoire', () {
      final m = neuve()..enregistrer('k', Resultat.rate);
      m.reinitialiser();
      expect(m.nombreSuivies, 0);
    });

    test('service : texte corrompu gardé en secours, rien écrasé en silence',
        () async {
      SharedPreferences.setMockInitialValues({
        MemoireService.kCle: '{abîmé',
        'emile_diamonds': 42,
      });
      final s = MemoireService();
      await s.charger(forcer: true);
      final prefs = await SharedPreferences.getInstance();
      expect(s.memoire.nombreSuivies, 0);
      expect(s.secoursCree, isTrue);
      expect(prefs.getString(MemoireService.kCleCorrompue), '{abîmé');
      expect(prefs.getString(MemoireService.kCle), '{abîmé'); // pas encore écrasé
      expect(prefs.getInt('emile_diamonds'), 42);

      await s.enregistrer('k', Resultat.premierCoup);
      expect(prefs.getString(MemoireService.kCleCorrompue), '{abîmé');
      expect(Memoire.lire(prefs.getString(MemoireService.kCle)).corrompue, isFalse);
    });

    test('service : sauvegarde puis rechargement, réinitialisation isolée',
        () async {
      SharedPreferences.setMockInitialValues({'emile_diamonds': 7});
      final s = MemoireService();
      await s.charger(forcer: true);
      await s.enregistrer('k', Resultat.rate);
      await s.charger(forcer: true);
      expect(s.memoire.etat('k'), isNotNull);
      await s.reinitialiser();
      final prefs = await SharedPreferences.getInstance();
      expect(Memoire.lire(prefs.getString(MemoireService.kCle)).memoire.nombreSuivies, 0);
      expect(prefs.getInt('emile_diamonds'), 7);
      expect(s.secoursCree, isFalse);
    });
  });
}

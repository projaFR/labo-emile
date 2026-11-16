import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/logic/memoire.dart';
import 'package:myapp/logic/sync_logic.dart';
import 'package:myapp/models/lesson_model.dart';
import 'package:myapp/services/labo_firebase_auth.dart';
import 'package:myapp/services/labo_firestore_client.dart';

LessonModel _lecon(String titre, {String? succes}) => LessonModel(
  titre: titre,
  succes: succes,
  astuces: const [FlashcardModel(question: 'Q', reponse: 'R')],
  exercices: const [],
  quiz: const [],
);

void main() {
  group('identifiantLeconSync & extraireCleOuJsonFirebase', () {
    test('identifiantLeconSync produit un id stable et sans accents', () {
      final id1 = identifiantLeconSync('Français', 'Pluriel en -OU');
      final id2 = identifiantLeconSync('Français', 'Pluriel en -OU');
      expect(id1, id2);
      expect(id1.startsWith('francais-pluriel-en-ou_'), isTrue);
      expect(RegExp(r'^[a-z0-9_-]+$').hasMatch(id1), isTrue);
    });

    test('extraireCleOuJsonFirebase lit clé brute et JSON complet', () {
      final brute = extraireCleOuJsonFirebase('  AIzaRawKey  ');
      expect(brute.projectId, 'reviser-bdd1a');
      expect(brute.webApiKey, 'AIzaRawKey');

      final json = extraireCleOuJsonFirebase(
        '{"projectId": "mon-proj", "webApiKey": "AIzaJsonKey"}',
      );
      expect(json.projectId, 'mon-proj');
      expect(json.webApiKey, 'AIzaJsonKey');
    });
  });

  group('LaboFirebaseAuth & LaboFirestoreClient', () {
    test('connexion, jeton et rafraîchissement automatique', () async {
      String? saved;
      var now = DateTime(2026, 11, 17, 1, 0);
      var appels = 0;

      final client = MockClient((req) async {
        appels++;
        if (req.url.host == 'identitytoolkit.googleapis.com') {
          return http.Response(
            jsonEncode({
              'localId': 'uid123',
              'email': 'labo@emile.local',
              'idToken': 'tok-1',
              'refreshToken': 'rt-1',
              'expiresIn': '3600',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'id_token': 'tok-2',
            'refresh_token': 'rt-2',
            'expires_in': '3600',
          }),
          200,
        );
      });

      final auth = LaboFirebaseAuth(
        lireStockage: () async => saved,
        ecrireStockage: (v) async => saved = v,
        client: client,
        horloge: () => now,
      );

      final cfg = await auth.connecter(
        projectId: 'reviser-bdd1a',
        webApiKey: 'AIza1',
        email: 'labo@emile.local',
        motDePasse: 'secret',
      );
      expect(cfg.uid, 'uid123');
      expect(saved, isNotNull);
      expect(saved!.contains('secret'), isFalse);

      expect(await auth.obtenirJetonValide(), 'tok-1');
      expect(appels, 1);

      now = now.add(const Duration(hours: 2));
      expect(await auth.obtenirJetonValide(), 'tok-2');
      expect(appels, 2);
      expect(auth.config!.refreshToken, 'rt-2');
    });

    test('traduction des erreurs auth en français', () async {
      final auth = LaboFirebaseAuth(
        lireStockage: () async => null,
        ecrireStockage: (_) async {},
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'INVALID_LOGIN_CREDENTIALS'},
            }),
            400,
          ),
        ),
      );
      await expectLater(
        () => auth.connecter(
          projectId: 'reviser-bdd1a',
          webApiKey: 'AIza1',
          email: 'labo@emile.local',
          motDePasse: 'faux',
        ),
        throwsA(
          isA<ErreurSyncLabo>().having(
            (e) => e.message,
            'message',
            contains('E-mail ou mot de passe incorrect'),
          ),
        ),
      );
    });

    test('LaboFirestoreClient lit, liste et écrit', () async {
      final fs = LaboFirestoreClient(
        projectId: 'reviser-bdd1a',
        jetonValide: () async => 'tok',
        client: MockClient((req) async {
          if (req.method == 'PATCH') {
            return http.Response('{}', 200);
          }
          if (req.url.path.endsWith('/documents/labo_lecons')) {
            return http.Response(
              jsonEncode({
                'documents': [
                  {
                    'name': 'projects/reviser-bdd1a/databases/(default)/documents/labo_lecons/doc1',
                    'fields': {
                      'matiere': {'stringValue': 'Maths'},
                      'supprimee': {'booleanValue': false},
                    },
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('', 404);
        }),
      );

      expect(await fs.lireDocument('labo_progression/emile'), isNull);
      final liste = await fs.listerCollection('labo_lecons');
      expect(liste['doc1']!['matiere'], 'Maths');
      await fs.ecrireDocument('labo_progression/emile', {'json': '{}'});
    });
  });

  group('fusionnerLecons & fusionnerProgression', () {
    test('fusionnerLecons échange dans les deux sens et propage suppression', () {
      final lLoc = _lecon('Locale', succes: '🚀 Fusée');
      final lDist = _lecon('Distante', succes: '🦉 Hibou');
      final idDist = identifiantLeconSync('Français', 'Distante');
      final lSup = _lecon('ASupprimer');
      final idSup = identifiantLeconSync('Maths', 'ASupprimer');

      final res = fusionnerLecons(
        localesCustom: {
          'Maths': [lLoc],
        },
        distantes: {
          idDist: LeconSyncDistante(
            id: idDist,
            matiere: 'Français',
            lecon: lDist,
            modifieLe: '2026-11-17T00:00:00Z',
          ),
          idSup: LeconSyncDistante(
            id: idSup,
            matiere: 'Maths',
            lecon: lSup,
            modifieLe: '2026-11-16T10:00:00Z',
          ),
        },
        suppressionsLocales: {idSup: '2026-11-17T01:00:00Z'},
        titresBase: {'Base'},
      );

      expect(res.localesFusionnees['Maths']!.map((l) => l.titre), ['Locale']);
      expect(res.localesFusionnees['Français']!.map((l) => l.titre), ['Distante']);
      expect(res.aEnvoyer.length, 2);
      expect(res.aEnvoyer.any((x) => !x.supprimee && x.lecon?.titre == 'Locale'), isTrue);
      expect(res.aEnvoyer.any((x) => x.supprimee && x.id == idSup), isTrue);
    });

    test('fusionnerProgression garde le meilleur et respecte resetLe', () {
      final mA = Memoire();
      mA.enregistrer('q1', Resultat.premierCoup);
      final mB = Memoire();
      mB.enregistrer('q1', Resultat.premierCoup);
      mB.enregistrer('q1', Resultat.premierCoup); // reps=2, boite=2
      mB.enregistrer('q2', Resultat.rate);

      final loc = ProgressionSync(
        diamants: 12,
        diamantsModifieLe: '2026-11-17T00:10:00Z',
        etoiles: {
          'L1': [true, false, false],
        },
        cartesDiamant: {'L1': '2026-11-16'},
        seanceVus: {'L1': ['0', '1']},
        memoireJson: mA.toJsonString(),
      );
      final dist = ProgressionSync(
        diamants: 20,
        diamantsModifieLe: '2026-11-17T00:15:00Z',
        etoiles: {
          'L1': [false, true, true],
        },
        cartesDiamant: {'L1': '2026-11-17'},
        seanceVus: {'L1': ['1', '2']},
        memoireJson: mB.toJsonString(),
      );

      final res = fusionnerProgression(loc, dist);
      expect(res.fusionnee.diamants, 20);
      expect(res.fusionnee.etoiles['L1'], [true, true, true]);
      expect(res.fusionnee.seanceVus['L1'], ['0', '1', '2']);
      final memF = Memoire.lire(res.fusionnee.memoireJson).memoire;
      expect(memF.etat('q1')!.reps, 2);
      expect(memF.etat('q2'), isNotNull);

      // Reset parental plus récent gagne.
      final reset = ProgressionSync(
        diamants: 0,
        diamantsModifieLe: '2026-11-17T00:20:00Z',
        resetLe: '2026-11-17T00:20:00Z',
        etoiles: const {},
        cartesDiamant: const {},
        seanceVus: const {},
        memoireJson: Memoire().toJsonString(),
      );
      final resReset = fusionnerProgression(reset, dist);
      expect(resReset.fusionnee.diamants, 0);
      expect(resReset.doitEnvoyer, isTrue);
    });
  });
}

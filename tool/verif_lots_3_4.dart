// Sans Flutter : dart --enable-asserts --packages=.dart_tool/package_config.json tool/verif_lots_3_4.dart
import 'dart:convert';
import 'dart:io';

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

Future<void> main() async {
  // 1. identifiantLeconSync & extraireCleOuJsonFirebase.
  final id1 = identifiantLeconSync('Français', 'Pluriel en -OU');
  final id2 = identifiantLeconSync('Français', 'Pluriel en -OU');
  assert(id1 == id2 && id1.startsWith('francais-pluriel-en-ou_'));
  assert(RegExp(r'^[a-z0-9_-]+$').hasMatch(id1));

  final brute = extraireCleOuJsonFirebase('  AIzaRawKey  ');
  assert(brute.projectId == 'reviser-bdd1a' && brute.webApiKey == 'AIzaRawKey');
  final jsonCfg = extraireCleOuJsonFirebase(
    '{"projectId": "proj-x", "webApiKey": "AIzaJsonKey"}',
  );
  assert(jsonCfg.projectId == 'proj-x' && jsonCfg.webApiKey == 'AIzaJsonKey');

  // 2. LaboFirebaseAuth (signInWithPassword + refresh + erreurs).
  String? saved;
  var now = DateTime(2026, 11, 17, 1, 0);
  var appels = 0;
  final auth = LaboFirebaseAuth(
    lireStockage: () async => saved,
    ecrireStockage: (v) async => saved = v,
    horloge: () => now,
    client: MockClient((req) async {
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
    }),
  );

  final cfg = await auth.connecter(
    projectId: 'reviser-bdd1a',
    webApiKey: 'AIzaTest',
    email: 'labo@emile.local',
    motDePasse: 'motdepasse',
  );
  assert(cfg.uid == 'uid123' && saved != null && !saved!.contains('motdepasse'));
  assert(await auth.obtenirJetonValide() == 'tok-1' && appels == 1);
  now = now.add(const Duration(hours: 2));
  assert(await auth.obtenirJetonValide() == 'tok-2' && appels == 2);
  assert(auth.config!.refreshToken == 'rt-2');

  final authErr = LaboFirebaseAuth(
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
  var msgErr = '';
  try {
    await authErr.connecter(
      projectId: 'reviser-bdd1a',
      webApiKey: 'AIzaTest',
      email: 'labo@emile.local',
      motDePasse: 'faux',
    );
  } on ErreurSyncLabo catch (e) {
    msgErr = e.message;
  }
  assert(msgErr.contains('E-mail ou mot de passe incorrect'));

  // 3. LaboFirestoreClient (encodage, décodage, get 404, list, set).
  String? derniereMethode;
  final fs = LaboFirestoreClient(
    projectId: 'reviser-bdd1a',
    jetonValide: () async => 'tok',
    client: MockClient((req) async {
      derniereMethode = req.method;
      if (req.method == 'PATCH') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final fields = body['fields'] as Map<String, dynamic>;
        assert(fields['json']['stringValue'] == '{"ok":true}');
        return http.Response('{}', 200);
      }
      if (req.url.path.endsWith('/documents/labo_lecons')) {
        return http.Response(
          jsonEncode({
            'documents': [
              {
                'name': 'projects/reviser-bdd1a/databases/(default)/documents/labo_lecons/d1',
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
  assert(await fs.lireDocument('labo_progression/emile') == null);
  final docs = await fs.listerCollection('labo_lecons');
  assert(docs['d1']!['matiere'] == 'Maths');
  await fs.ecrireDocument('labo_progression/emile', {'json': '{"ok":true}'});
  assert(derniereMethode == 'PATCH');

  // 4. fusionnerLecons (ajout local, ajout distant, suppression, base ignorée).
  final lLoc = _lecon('Locale', succes: '🚀 Fusée');
  final lDist = _lecon('Distante', succes: '🦉 Hibou');
  final idDist = identifiantLeconSync('Français', 'Distante');
  final lSup = _lecon('ASupprimer');
  final idSup = identifiantLeconSync('Maths', 'ASupprimer');
  final lBase = _lecon('Base');

  final resL = fusionnerLecons(
    localesCustom: {
      'Maths': [lLoc, lBase],
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
  assert(resL.localesFusionnees['Maths']!.length == 1);
  assert(resL.localesFusionnees['Maths']!.first.titre == 'Locale');
  assert(resL.localesFusionnees['Français']!.first.titre == 'Distante');
  assert(resL.aEnvoyer.length == 2);
  assert(resL.aEnvoyer.any((x) => x.supprimee && x.id == idSup));

  // 5. fusionnerMemoires & fusionnerProgression (dont resetLe).
  final mA = Memoire();
  mA.enregistrer('q1', Resultat.premierCoup);
  final mB = Memoire();
  mB.enregistrer('q1', Resultat.premierCoup);
  mB.enregistrer('q1', Resultat.premierCoup);
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
  final resP = fusionnerProgression(loc, dist);
  assert(resP.fusionnee.diamants == 20);
  assert(resP.fusionnee.etoiles['L1']![0] && resP.fusionnee.etoiles['L1']![2]);
  assert(resP.fusionnee.seanceVus['L1']!.length == 3);
  final memF = Memoire.lire(resP.fusionnee.memoireJson).memoire;
  assert(memF.etat('q1')!.reps == 2 && memF.etat('q2') != null);

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
  assert(resReset.fusionnee.diamants == 0 && resReset.doitEnvoyer);

  stdout.writeln('OK: toutes les assertions des lots 3 et 4 ont reussi.');
}

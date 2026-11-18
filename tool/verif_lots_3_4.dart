// Sans Flutter : dart --enable-asserts --packages=.dart_tool/package_config.json tool/verif_lots_3_4.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/logic/accueil_logic.dart';
import 'package:myapp/logic/lecon_json_logic.dart';
import 'package:myapp/logic/memoire.dart';
import 'package:myapp/logic/suivi_parent_logic.dart';
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
    leconsBaseSupprimees: ['Stratégies Multiplications'],
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
    leconsBaseSupprimees: ['Pluriel en -OU'],
  );
  final resP = fusionnerProgression(loc, dist);
  assert(resP.fusionnee.diamants == 20);
  assert(resP.fusionnee.etoiles['L1']![0] && resP.fusionnee.etoiles['L1']![2]);
  assert(resP.fusionnee.seanceVus['L1']!.length == 3);
  assert(resP.fusionnee.leconsBaseSupprimees.length == 2);
  assert(
    ProgressionSync.tryFromJsonString(resP.fusionnee.toJsonString())!
            .leconsBaseSupprimees
            .length ==
        2,
  );
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

  // 6. SHA-256 Dart pur, ConfigOAuthGoogleLabo, signInWithIdp & loopback OAuth2.
  String hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  assert(
    hex(sha256Bytes(const [])) ==
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
  );
  assert(
    hex(sha256Bytes(utf8.encode('abc'))) ==
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
  );

  assert(
    ConfigOAuthGoogleLabo.tryParse(
          '{"projectId":"reviser-bdd1a","webApiKey":"COLLE_ICI","desktopClientId":"cid","desktopClientSecret":"csec"}',
        ) ==
        null,
  );
  final oauthCfg = ConfigOAuthGoogleLabo.tryParse(
    '{"projectId":"reviser-bdd1a","webApiKey":"AIzaOk","desktopClientId":"cid-1","desktopClientSecret":"csec-1"}',
  );
  assert(oauthCfg != null && oauthCfg.desktopClientId == 'cid-1');
  if (oauthCfg == null) throw StateError('Config OAuth invalide');

  final idTokenRecu = await obtenirIdTokenGoogleLoopback(
    oauthConfig: oauthCfg,
    client: MockClient((req) async {
      assert(req.url.toString() == 'https://oauth2.googleapis.com/token');
      assert(req.bodyFields['code'] == 'auth-code-99');
      assert(req.bodyFields['client_id'] == 'cid-1');
      assert(req.bodyFields['client_secret'] == 'csec-1');
      assert((req.bodyFields['code_verifier'] ?? '').isNotEmpty);
      return http.Response(jsonEncode({'id_token': 'google-jwt-ok'}), 200);
    }),
    ouvrirNavigateur: (authUri) async {
      final redir = Uri.parse(authUri.queryParameters['redirect_uri']!);
      final state = authUri.queryParameters['state']!;
      assert(authUri.queryParameters['code_challenge_method'] == 'S256');
      // Le navigateur revient sur 127.0.0.1 de façon asynchrone après ouverture.
      unawaited(() async {
        final httpClient = HttpClient();
        try {
          final r = await httpClient.getUrl(
            redir.replace(
              queryParameters: {'code': 'auth-code-99', 'state': state},
            ),
          );
          final resp = await r.close();
          assert(resp.statusCode == 200);
          await resp.drain<void>();
        } finally {
          httpClient.close();
        }
      }());
      return true;
    },
  );
  assert(idTokenRecu == 'google-jwt-ok');

  String? savedGoogle;
  final authGoogle = LaboFirebaseAuth(
    lireStockage: () async => savedGoogle,
    ecrireStockage: (v) async => savedGoogle = v,
    client: MockClient((req) async {
      assert(req.url.path == '/v1/accounts:signInWithIdp');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      assert(body['postBody'] == 'id_token=google-jwt-ok&providerId=google.com');
      return http.Response(
        jsonEncode({
          'localId': 'uid-g',
          'email': 'thibaut@gmail.com',
          'idToken': 'fb-tok-g',
          'refreshToken': 'fb-rt-g',
          'expiresIn': '3600',
        }),
        200,
      );
    }),
  );
  final cfgG = await authGoogle.connecterAvecGoogleIdToken(
    projectId: oauthCfg.projectId,
    webApiKey: oauthCfg.webApiKey,
    googleIdToken: idTokenRecu,
    desktopClientId: oauthCfg.desktopClientId,
    desktopClientSecret: oauthCfg.desktopClientSecret,
  );
  assert(cfgG.email == 'thibaut@gmail.com');
  assert(ConfigFirebaseLabo.tryParse(savedGoogle)?.desktopClientId == 'cid-1');

  // 7. Suivi parent détaillé & questions masquées.
  final lSuivi = _lecon('Fractions');
  final qSuivi = questionsDeLecon(lSuivi).first;
  final mSuivi = Memoire()..enregistrer(qSuivi.cle, Resultat.rate);
  final refsSuivi = [LeconRef('Maths', lSuivi)];
  assert(calculerResumesLecons(refsSuivi, mSuivi).first.totalQuestions == 1);
  assert(topQuestionsRatees(refsSuivi, mSuivi).first.ratees == 1);
  assert(
    topQuestionsRatees(refsSuivi, mSuivi, masquees: {qSuivi.cle}).isEmpty,
  );
  assert(listerQuestionsMasquees(refsSuivi, mSuivi, {qSuivi.cle}).length == 1);

  final progMasq = ProgressionSync(
    diamants: 1,
    diamantsModifieLe: '2026-11-18T10:00:00Z',
    etoiles: const {},
    cartesDiamant: const {},
    seanceVus: const {},
    memoireJson: Memoire().toJsonString(),
    questionsMasquees: [qSuivi.cle],
  );
  assert(
    ProgressionSync.tryFromJsonString(progMasq.toJsonString())!
            .questionsMasquees
            .single ==
        qSuivi.cle,
  );

  // 8. Lot D & E : saisieMot, vraiFaux, reponsesAcceptees, explication & rejet type inconnu.
  final leconLotD = analyserJsonLecon(jsonEncode({
    'matiere': 'Français',
    'titre': 'Pluriel -ou',
    'astuces': [],
    'exercices': [
      {
        'type': 'saisieMot',
        'question': 'Des [?] (hibou)',
        'consigne': 'Écris au pluriel :',
        'reponseAttendue': 'hiboux',
        'reponsesAcceptees': ['des hiboux'],
        'astuceErreur': 'Pense aux 7 exceptions.',
        'explication': 'Hibou prend un -x au pluriel.',
      },
      {
        'type': 'vraiFaux',
        'question': 'Le mot « bijou » prend un -x au pluriel.',
        'consigne': 'Vrai ou Faux ?',
        'reponseAttendue': 'Vrai',
        'astuceErreur': 'Pense à la liste des 7 mots.',
      },
      {
        'type': 'ordre',
        'question': 'Range du plus petit au plus grand :',
        'consigne': 'Clique dans le bon ordre :',
        'reponsesMultiples': ['12', '45', '108'],
        'astuceErreur': 'Compare les centaines d’abord.',
      },
      {
        'type': 'association',
        'question': 'Relie chaque calcul à son résultat :',
        'consigne': 'Associe les paires :',
        'options': ['3 x 4', '5 x 5'],
        'reponsesMultiples': ['12', '25'],
        'astuceErreur': 'Révise les tables de 3 et 5.',
      },
      {
        'type': 'classement',
        'question': 'Classe ces mots :',
        'consigne': 'Range dans la bonne boîte :',
        'options': ['chien', 'courir', 'table'],
        'reponsesMultiples': ['Nom', 'Verbe', 'Nom'],
        'astuceErreur': 'Le verbe indique une action.',
      },
    ],
    'quiz': [],
  }));
  final exD = leconLotD.lecon.exercices.first;
  assert(exD.estSaisieMot && exD.reponsesAcceptees.single == 'des hiboux');
  assert(exD.explication == 'Hibou prend un -x au pluriel.');
  assert(leconLotD.lecon.exercices[1].type == ExerciseType.textQcm);
  assert(leconLotD.lecon.exercices[2].type == ExerciseType.ordre);
  assert(leconLotD.lecon.exercices[3].type == ExerciseType.association);
  assert(leconLotD.lecon.exercices[4].type == ExerciseType.classement);

  var typeInconnuRefuse = false;
  try {
    analyserJsonLecon(jsonEncode({
      'titre': 'Futur',
      'exercices': [
        {
          'type': 'typeFuturInconnu',
          'question': 'Q ?',
          'astuceErreur': 'A',
        },
      ],
    }));
  } on FormatException catch (e) {
    typeInconnuRefuse = e.message.contains('Mets l\'appli à jour');
  }
  assert(typeInconnuRefuse);

  stdout.writeln('OK: toutes les assertions des lots 3 et 4 ont reussi.');
}

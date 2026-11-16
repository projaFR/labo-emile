// Sans Flutter : dart --enable-asserts --packages=.dart_tool/package_config.json tool/verif_lots_1_2.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/logic/accueil_logic.dart';
import 'package:myapp/logic/lecon_json_logic.dart';
import 'package:myapp/logic/memoire.dart';
import 'package:myapp/logic/trophees_logic.dart';
import 'package:myapp/models/lesson_model.dart';
import 'package:myapp/services/gemini_lecon_service.dart';

String _jsonExemple({String? succes = '🦉 Dompteur de Hiboux à Genoux'}) =>
    jsonEncode({
      'matiere': 'Français',
      'titre': 'Le pluriel des noms en -ou',
      if (succes != null) 'succes': succes,
      'astuces': [
        {
          'question': 'Quels sont les 7 noms en -ou qui prennent un X ?',
          'reponse': 'bijou, caillou, chou, genou, hibou, joujou, pou.',
        },
      ],
      'exercices': [
        {
          'question': 'Un hibou -> des [?]',
          'consigne': 'Choisis le bon mot :',
          'options': ['hiboux', 'cailloux', 'genoux', 'bijoux'],
          'reponseAttendue': 'hiboux',
          'astuceErreur': "Pense à l'oiseau de nuit.",
        },
        {
          'question': '14 x 2 = ([?] x 2) + ([?] x 2)',
          'consigne': 'Décompose 14 :',
          'reponsesMultiples': ['10', '4'],
          'astuceErreur': '14 = 10 + 4.',
        },
      ],
      'quiz': [
        {
          'question': 'Lequel prend un X au pluriel ?',
          'options': ['clou', 'genou', 'trou', 'sou'],
          'indexCorrect': 1,
        },
      ],
    });

Future<void> main() async {
  // 1. LessonModel.toJson / fromJson avec et sans succes.
  const avecSucces = LessonModel(
    titre: 'Multiplications',
    succes: '🧮 Architecte des Nombres',
    astuces: [FlashcardModel(question: 'Q', reponse: 'R')],
    exercices: [],
    quiz: [],
  );
  final roundTripAvec = LessonModel.fromJson(avecSucces.toJson());
  assert(roundTripAvec.titre == 'Multiplications');
  assert(roundTripAvec.succes == '🧮 Architecte des Nombres');

  const sansSucces = LessonModel(
    titre: 'Ancienne leçon',
    astuces: [],
    exercices: [],
    quiz: [],
  );
  final mapSans = sansSucces.toJson();
  assert(!mapSans.containsKey('succes'));
  final roundTripSans = LessonModel.fromJson(mapSans);
  assert(roundTripSans.succes == null);

  // 2. separerBadgeSucces, choisirCleIconeBadge & galerieBadgesLecons (niveaux).
  final s1 = separerBadgeSucces('🦉 Dompteur de Hiboux', 'Pluriel');
  assert(s1.emoji == '🦉' && s1.nom == 'Dompteur de Hiboux');
  final s2 = separerBadgeSucces('As du Calcul', 'Calcul');
  assert(s2.emoji == '🏅' && s2.nom == 'As du Calcul');
  final s3 = separerBadgeSucces(null, 'Les Fractions');
  assert(s3.emoji == '🏅' && s3.nom == 'Champion · Les Fractions');

  assert(choisirCleIconeBadge('Dompteur de Hiboux', 'Pluriel', 'Français') == 'hibou');
  assert(choisirCleIconeBadge('Architecte des Nombres', 'Multiplications', 'Maths') == 'compas');
  assert(choisirCleIconeBadge('Pilote de Fusée', 'Espace', 'Sciences') == 'fusee');
  assert(choisirCleIconeBadge('As de la Plume', 'Accords', 'Français') == 'plume');

  const lecon4Q = LessonModel(
    titre: 'Multiplications',
    succes: '🧮 Architecte des Nombres',
    astuces: [
      FlashcardModel(question: 'Q1', reponse: 'R1'),
      FlashcardModel(question: 'Q2', reponse: 'R2'),
    ],
    exercices: [
      ExerciseModel(question: 'E1', consigne: 'C', astuceErreur: 'A'),
      ExerciseModel(question: 'E2', consigne: 'C', astuceErreur: 'A'),
    ],
    quiz: [],
  );
  const refA = LeconRef('Maths', lecon4Q);
  final refB = const LeconRef('Français', sansSucces);
  final galerie = galerieBadgesLecons(
    [refA, refB],
    (t) => t == 'Multiplications' ? [true, true, true] : [true, true, false],
  );
  assert(galerie.length == 2);
  assert(galerie[0].debloque && galerie[0].niveau == NiveauBadge.bronze);
  assert(galerie[0].cleIcone == 'compas' && galerie[0].nom == 'Architecte des Nombres');
  assert(!galerie[1].debloque && galerie[1].niveau == NiveauBadge.verrouille && galerie[1].etoiles == 2);
  assert(galerie[1].nom == 'Champion · Ancienne leçon');

  final galerie0 = galerieBadgesLecons([refA], (_) => [false, false, false]);
  assert(!galerie0.first.debloque && galerie0.first.niveau == NiveauBadge.verrouille);

  // Évolution Bronze -> Argent -> Or -> Diamant via Memoire.
  final refs4 = questionsDeLecon(lecon4Q);
  final memArgent = Memoire(
    etats: {
      refs4[0].cle: const EtatQuestion(boite: 2, retour: '2026-11-20'),
      refs4[1].cle: const EtatQuestion(boite: 2, retour: '2026-11-20'),
    },
  );
  assert(
    badgePourLecon(refA, [true, true, true], memoire: memArgent).niveau ==
        NiveauBadge.argent,
  );
  final memOr = Memoire(
    etats: {
      refs4[0].cle: const EtatQuestion(boite: 3, retour: '2026-11-22'),
      refs4[1].cle: const EtatQuestion(boite: 3, retour: '2026-11-22'),
    },
  );
  assert(
    badgePourLecon(refA, [true, true, true], memoire: memOr).niveau ==
        NiveauBadge.or,
  );
  final memDiamant = Memoire(
    etats: {
      for (final r in refs4)
        r.cle: const EtatQuestion(boite: 3, retour: '2026-11-22'),
    },
  );
  assert(
    badgePourLecon(refA, [true, true, true], memoire: memDiamant).niveau ==
        NiveauBadge.diamant,
  );

  // 3. nettoyerJsonLecon et analyserJsonLecon.
  final brut = 'Blabla\n```json\n${_jsonExemple()}\n```\nFin';
  final importee = analyserJsonLecon(brut);
  assert(importee.matiere == 'Français');
  assert(importee.lecon.titre == 'Le pluriel des noms en -ou');
  assert(importee.lecon.succes == '🦉 Dompteur de Hiboux à Genoux');
  assert(importee.lecon.exercices.length == 2);
  assert(importee.lecon.quiz.length == 1);

  void doitEchouer(String input) {
    var echec = false;
    try {
      analyserJsonLecon(input);
    } on FormatException {
      echec = true;
    }
    assert(echec, 'Devait lever FormatException pour: $input');
  }

  doitEchouer('');
  doitEchouer('{"titre": ""}');
  doitEchouer(jsonEncode({'titre': 'Vide'}));
  doitEchouer(
    jsonEncode({
      'titre': 'Trous sans reponsesMultiples',
      'exercices': [
        {'question': '[?] + [?] = 5'},
      ],
    }),
  );
  doitEchouer(
    jsonEncode({
      'titre': 'Nombre de reponsesMultiples faux',
      'exercices': [
        {
          'question': '[?] + [?] = 5',
          'reponsesMultiples': ['2'],
        },
      ],
    }),
  );
  doitEchouer(
    jsonEncode({
      'titre': 'Quiz indexCorrect hors limites',
      'quiz': [
        {
          'question': 'Q',
          'options': ['A', 'B'],
          'indexCorrect': 2,
        },
      ],
    }),
  );

  // 4. MIME & masquage clé.
  assert(detecterMimeType('x', [0xFF, 0xD8, 0xFF, 0xE0]) == 'image/jpeg');
  assert(detecterMimeType('x', [0x89, 0x50, 0x4E, 0x47]) == 'image/png');
  assert(masquerCleGemini(null) == 'Aucune clé configurée');
  assert(masquerCleGemini('AIzaAbcd1234') == 'Clé configurée (••••1234)');

  // 5. genererLeconDepuisPhotos avec MockClient.
  final photo = PhotoLecon(
    octets: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
    mimeType: 'image/jpeg',
    nom: 'photo.jpg',
  );

  // 5a. Succès du 1er coup.
  var appels = 0;
  final clientOk = MockClient((req) async {
    appels++;
    assert(req.headers['x-goog-api-key'] == 'AIzaCleTest');
    return http.Response(
      jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': _jsonExemple()},
              ],
            },
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  final r1 = await genererLeconDepuisPhotos(
    apiKey: 'AIzaCleTest',
    photos: [photo],
    commentaireParent: 'CE2',
    client: clientOk,
  );
  assert(appels == 1 && r1.lecon.succes == '🦉 Dompteur de Hiboux à Genoux');

  // 5b. Correction automatique au 2e essai après 1er JSON mal formé.
  var appelsRetry = 0;
  final clientRetry = MockClient((req) async {
    appelsRetry++;
    final text = appelsRetry == 1
        ? '{"titre": "Cassé", "exercices": [{"question": "[?] + [?] = 2"}]}'
        : _jsonExemple();
    return http.Response(
      jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': text},
              ],
            },
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  final r2 = await genererLeconDepuisPhotos(
    apiKey: 'AIzaCleTest',
    photos: [photo],
    client: clientRetry,
  );
  assert(appelsRetry == 2 && r2.lecon.titre == 'Le pluriel des noms en -ou');

  // 5c. Erreurs 401/403 et 429.
  for (final code in [401, 403]) {
    var erreurRecue = '';
    try {
      await genererLeconDepuisPhotos(
        apiKey: 'mauvaise',
        photos: [photo],
        client: MockClient((_) async => http.Response('{}', code)),
      );
    } on ErreurGeminiLecon catch (e) {
      erreurRecue = e.message;
    }
    assert(erreurRecue.contains('Clé Gemini refusée'));
  }

  var erreurQuota = '';
  try {
    await genererLeconDepuisPhotos(
      apiKey: 'AIzaCleTest',
      photos: [photo],
      client: MockClient((_) async => http.Response('{}', 429)),
    );
  } on ErreurGeminiLecon catch (e) {
    erreurQuota = e.message;
  }
  assert(erreurQuota.contains('Limite gratuite Gemini atteinte'));

  stdout.writeln('OK: toutes les assertions des lots 1 et 2 ont reussi.');
}

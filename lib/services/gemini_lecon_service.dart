import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../logic/lecon_json_logic.dart';

/// Modèle Gemini gratuit et rapide adapté à la lecture de photos de cahiers.
const String kModeleGeminiLecon = 'gemini-3.5-flash-lite';

String _modeleGeminiActif = kModeleGeminiLecon;

/// Réinitialise le cache du modèle actif (utile pour les tests).
void reinitialiserModeleGeminiCache() {
  _modeleGeminiActif = kModeleGeminiLecon;
}

class _ModeleGeminiIndisponibleException implements Exception {
  final ErreurGeminiLecon erreurDirecte;
  const _ModeleGeminiIndisponibleException(this.erreurDirecte);
}

const List<String> _motsExclusModeleGemini = [
  'embedding',
  'imagen',
  'veo',
  'tts',
  'audio',
  'live',
  'aqa',
  'gemma',
  'learnlm',
  'robotics',
  'computer-use',
  'thinking',
  'image',
];

/// Classe les modèles retournés par `/v1beta/models` pour choisir le meilleur
/// modèle multimodal rapide supportant `generateContent`.
List<String> classerModelesGeminiDisponibles(
  List<dynamic> modelsJson, {
  Set<String> exclus = const {},
}) {
  final regVersion = RegExp(r'^gemini-(\d+(?:\.\d+)?)');
  final candidats = <({String id, int score})>[];

  for (final item in modelsJson) {
    if (item is! Map) continue;
    final rawName = item['name'];
    final methods = item['supportedGenerationMethods'];
    if (rawName is! String || methods is! List) continue;
    if (!methods.contains('generateContent')) continue;

    final id = rawName.startsWith('models/')
        ? rawName.substring('models/'.length)
        : rawName;
    if (id.isEmpty || exclus.contains(id) || !id.startsWith('gemini-')) {
      continue;
    }
    if (_motsExclusModeleGemini.any(id.contains)) continue;

    var score = 0;
    if (id.contains('flash')) score += 1000;
    if (id.contains('flash-lite')) score += 300;
    if (id == 'gemini-flash-lite-latest' || id == 'gemini-flash-latest') {
      score += 150;
    }
    if (!id.contains('preview') && !id.contains('exp')) score += 50;
    final m = regVersion.firstMatch(id);
    if (m != null) {
      final ver = double.tryParse(m.group(1)!) ?? 0;
      score += (ver * 20).round();
    }
    candidats.add((id: id, score: score));
  }

  candidats.sort((a, b) {
    final diff = b.score.compareTo(a.score);
    return diff != 0 ? diff : b.id.compareTo(a.id);
  });
  return [for (final c in candidats) c.id];
}

/// Interroge `/v1beta/models` pour découvrir les modèles compatibles disponibles.
Future<List<String>> listerModelesGeminiCompatibles({
  required http.Client client,
  required String apiKey,
  required Duration timeout,
  Set<String> exclus = const {},
}) async {
  final uri = Uri.https('generativelanguage.googleapis.com', '/v1beta/models');
  final http.Response res;
  try {
    res = await client
        .get(uri, headers: {'x-goog-api-key': apiKey})
        .timeout(timeout);
  } on TimeoutException {
    throw const ErreurGeminiLecon(
      'Gemini a mis trop de temps à répondre. Réessaie dans un instant.',
    );
  } catch (_) {
    throw const ErreurGeminiLecon(
      'Impossible de joindre Gemini. Vérifie la connexion internet.',
    );
  }

  _verifierStatutHttpGemini(res.statusCode);

  try {
    final json = jsonDecode(res.body);
    if (json is! Map<String, dynamic>) return const [];
    final models = json['models'];
    if (models is! List) return const [];
    return classerModelesGeminiDisponibles(models, exclus: exclus);
  } catch (_) {
    return const [];
  }
}

/// Photo sélectionnée ou prise pour générer une leçon.
class PhotoLecon {
  final Uint8List octets;
  final String mimeType;
  final String nom;

  const PhotoLecon({
    required this.octets,
    required this.mimeType,
    required this.nom,
  });
}

/// Erreur lisible en français lors de la génération d'une leçon avec Gemini.
class ErreurGeminiLecon implements Exception {
  final String message;

  const ErreurGeminiLecon(this.message);

  @override
  String toString() => message;
}

/// Consigne pédagogique complète donnée à Gemini pour fabriquer la leçon.
const String kPromptSystemeGeminiLecon = '''
Tu es un professeur des écoles bienveillant et rigoureux (cycle 2, niveau CE2, pour Émile, 8 ans).
À partir de la ou des photos d'une leçon de classe, fabrique une leçon complète pour l'application « Le Labo d'Émile ».

Règles strictes :
1. Réponds UNIQUEMENT avec un objet JSON valide, sans texte ni commentaire autour.
2. Champs attendus :
   - "matiere" : une parmi ["Mathématiques", "Français", "Sciences", "Histoire", "Géographie", "Anglais"].
   - "titre" : titre CLASSIQUE et scolaire de la leçon (ex : "Le pluriel des noms en -ou", "Multiplier par 10, 100, 1000").
   - "succes" : 1 emoji suivi d'un espace puis d'un petit nom de badge RIGOLO et valorisant lié au thème de la leçon (ex : "🦉 Dompteur de Hiboux à Genoux", "🚀 Pilote des Grands Nombres").
   - "astuces" : liste de 4 à 6 cartes courtes {"question": "...", "reponse": "..."} résumant les règles et exemples de la feuille avec les mots exacts enseignés en classe.
   - "exercices" : liste de 10 exercices de difficulté progressive (découverte, entraînement, défi), tous reliés aux notions de la leçon :
       * Pour une réponse numérique / calcul :
         - mets un ou plusieurs "[?]" dans "question",
         - laisse "options" vide ("options": []),
         - s'il y a 1 seul "[?]", remplis "reponseAttendue" (nombre sans espaces, ex : "1000"),
         - s'il y a 2 "[?]" ou plus, remplis "reponsesMultiples" avec autant d'éléments exacts que de "[?]".
       * Pour un mot à écrire (orthographe, conjugaison, vocabulaire — à privilégier sur les QCM en orthographe) :
         - mets "type": "saisieMot", 1 "[?]" dans "question" (ex : "Des [?] (hibou)"),
         - laisse "options" vide ("options": []),
         - mets le mot attendu dans "reponseAttendue" (ex : "hiboux"),
         - ajoute facultativement "reponsesAcceptees": [...] s'il y a plusieurs écritures justes.
       * Pour une affirmation Vrai ou Faux :
         - mets "type": "vraiFaux", "options": ["Vrai", "Faux"], et "reponseAttendue": "Vrai" ou "Faux".
       * Pour remettre des nombres ou des mots dans l'ordre :
         - mets "type": "ordre", laisse "options": [], et mets la liste dans le BON ordre dans "reponsesMultiples" (au moins 3 éléments).
       * Pour une règle ou du français (QCM) :
         - mets 0 ou 1 "[?]" dans "question",
         - fournis exactement 4 "options",
         - mets dans "reponseAttendue" la copie exacte de la bonne option.
         - INTERDIT d'inventer des mots mal orthographiés dans les options (utilise d'autres vrais mots français ou des erreurs de règle plausibles).
       * Champs de chaque exercice : "question", "consigne", "reponseAttendue", "reponsesMultiples", "options", "astuceErreur", et facultativement "type", "reponsesAcceptees", "explication" (courte explication affichée après la réponse).
       * "astuceErreur" : indice court (moins de 15 mots) qui aide à réfléchir sans jamais donner la réponse.
   - "quiz" : liste de 5 questions courtes (lisibles en moins de 5 s) pour le Défi Chrono :
       {"question": "...", "options": ["...", "...", "...", "..."], "indexCorrect": 0} (indexCorrect entre 0 et 3).
''';

/// Envoie les [photos] à Gemini et renvoie la leçon validée prête à importer.
Future<LeconImportee> genererLeconDepuisPhotos({
  required String apiKey,
  required List<PhotoLecon> photos,
  String commentaireParent = '',
  http.Client? client,
  Duration timeout = const Duration(seconds: 120),
  void Function(int jetons)? surUtilisation,
}) async {
  final cle = apiKey.trim();
  if (cle.isEmpty) {
    throw const ErreurGeminiLecon(
      "Configure d'abord ta clé Gemini gratuite.",
    );
  }
  if (photos.isEmpty) {
    throw const ErreurGeminiLecon(
      'Ajoute au moins une photo de la leçon.',
    );
  }

  final c = client ?? http.Client();
  final doitFermer = client == null;
  try {
    final precision = commentaireParent.trim();
    final consigne = precision.isEmpty
        ? 'Crée la leçon complète au format JSON à partir de ces photos.'
        : 'Crée la leçon complète au format JSON à partir de ces photos.\n'
            'Précision du parent : $precision';

    final parts = <Map<String, dynamic>>[
      for (final p in photos)
        {
          'inlineData': {
            'mimeType': p.mimeType,
            'data': base64Encode(p.octets),
          },
        },
      {'text': consigne},
    ];

    final contents = <Map<String, dynamic>>[
      {'role': 'user', 'parts': parts},
    ];

    final texte = await _appelerAvecRepliModele(
      client: c,
      apiKey: cle,
      contents: contents,
      timeout: timeout,
      surUtilisation: surUtilisation,
    );

    try {
      return analyserJsonLecon(texte);
    } on FormatException catch (e) {
      // Un seul essai de correction automatique si le format JSON présente une anomalie.
      final correctionContents = <Map<String, dynamic>>[
        ...contents,
        {
          'role': 'model',
          'parts': [
            {'text': texte},
          ],
        },
        {
          'role': 'user',
          'parts': [
            {
              'text':
                  'Ta réponse JSON ne passe pas le contrôle technique (${e.message}). '
                  'Corrige uniquement le format et renvoie uniquement le JSON complet valide.',
            },
          ],
        },
      ];
      final texteCorrige = await _appelerAvecRepliModele(
        client: c,
        apiKey: cle,
        contents: correctionContents,
        timeout: timeout,
        surUtilisation: surUtilisation,
      );
      try {
        return analyserJsonLecon(texteCorrige);
      } on FormatException catch (e2) {
        throw ErreurGeminiLecon(
          'Gemini a répondu un format invalide : ${e2.message}',
        );
      }
    }
  } finally {
    if (doitFermer) c.close();
  }
}

void _verifierStatutHttpGemini(
  int statusCode, {
  bool autoriserRepli = false,
}) {
  if (statusCode == 400 || statusCode == 401 || statusCode == 403) {
    throw const ErreurGeminiLecon(
      'Clé Gemini refusée. Vérifie ta clé dans l’Espace Parent.',
    );
  }
  if (statusCode == 404) {
    const err = ErreurGeminiLecon(
      'Aucun modèle Gemini compatible trouvé pour cette clé (erreur 404).',
    );
    if (autoriserRepli) throw const _ModeleGeminiIndisponibleException(err);
    throw err;
  }
  if (statusCode == 429) {
    const err = ErreurGeminiLecon(
      'Limite gratuite Gemini atteinte pour l’instant. Réessaie dans une minute.',
    );
    if (autoriserRepli) throw const _ModeleGeminiIndisponibleException(err);
    throw err;
  }
  if (statusCode < 200 || statusCode >= 300) {
    final err = ErreurGeminiLecon(
      'Gemini a renvoyé une erreur (code $statusCode). Réessaie.',
    );
    if (autoriserRepli && statusCode >= 500) {
      throw _ModeleGeminiIndisponibleException(err);
    }
    throw err;
  }
}

Future<String> _appelerAvecRepliModele({
  required http.Client client,
  required String apiKey,
  required List<Map<String, dynamic>> contents,
  required Duration timeout,
  void Function(int jetons)? surUtilisation,
}) async {
  final timeoutParEssai =
      timeout.inSeconds > 25 ? const Duration(seconds: 25) : timeout;
  final initial = _modeleGeminiActif;
  try {
    return await _appelerGemini(
      client: client,
      modele: initial,
      apiKey: apiKey,
      contents: contents,
      timeout: timeoutParEssai,
      autoriserRepli: true,
      surUtilisation: surUtilisation,
    );
  } on _ModeleGeminiIndisponibleException catch (premierEchec) {
    final candidats = await listerModelesGeminiCompatibles(
      client: client,
      apiKey: apiKey,
      timeout: timeoutParEssai,
      exclus: {initial},
    );
    var derniereErreur = premierEchec.erreurDirecte;
    for (final candidat in candidats.take(3)) {
      try {
        final reponse = await _appelerGemini(
          client: client,
          modele: candidat,
          apiKey: apiKey,
          contents: contents,
          timeout: timeoutParEssai,
          autoriserRepli: true,
          surUtilisation: surUtilisation,
        );
        _modeleGeminiActif = candidat;
        return reponse;
      } on _ModeleGeminiIndisponibleException catch (e) {
        derniereErreur = e.erreurDirecte;
        continue;
      }
    }
    throw derniereErreur;
  }
}

Future<String> _appelerGemini({
  required http.Client client,
  required String modele,
  required String apiKey,
  required List<Map<String, dynamic>> contents,
  required Duration timeout,
  bool autoriserRepli = false,
  void Function(int jetons)? surUtilisation,
}) async {
  final uri = Uri.https(
    'generativelanguage.googleapis.com',
    '/v1beta/models/$modele:generateContent',
  );
  final corps = jsonEncode({
    'systemInstruction': {
      'parts': [
        {'text': kPromptSystemeGeminiLecon},
      ],
    },
    'contents': contents,
    'generationConfig': {
      'responseMimeType': 'application/json',
      'temperature': 0.3,
    },
  });

  final http.Response res;
  try {
    res = await client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: corps,
        )
        .timeout(timeout);
  } on TimeoutException {
    const err = ErreurGeminiLecon(
      'Gemini a mis trop de temps à répondre. Réessaie dans un instant.',
    );
    if (autoriserRepli) throw const _ModeleGeminiIndisponibleException(err);
    throw err;
  } catch (_) {
    throw const ErreurGeminiLecon(
      'Impossible de joindre Gemini. Vérifie la connexion internet.',
    );
  }

  _verifierStatutHttpGemini(res.statusCode, autoriserRepli: autoriserRepli);

  try {
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final usage = json['usageMetadata'];
    final jetons = usage is Map ? (usage['totalTokenCount'] as int?) ?? 0 : 0;
    surUtilisation?.call(jetons);
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw const ErreurGeminiLecon(
        'Gemini n’a retourné aucune leçon. Essaie avec une photo plus nette.',
      );
    }
    final first = candidates.first as Map<String, dynamic>;
    final content = first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw const ErreurGeminiLecon(
        'Réponse Gemini vide. Essaie avec une photo plus nette.',
      );
    }
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map && part['text'] is String) {
        buffer.write(part['text'] as String);
      }
    }
    final texte = buffer.toString().trim();
    if (texte.isEmpty) {
      throw const ErreurGeminiLecon(
        'Réponse Gemini vide. Essaie avec une photo plus nette.',
      );
    }
    return texte;
  } on ErreurGeminiLecon {
    rethrow;
  } catch (_) {
    throw const ErreurGeminiLecon(
      'Réponse de Gemini illisible. Réessaie.',
    );
  }
}

/// Détecte le type MIME d'une image d'après ses premiers octets ou son nom.
String detecterMimeType(String nom, List<int> octets) {
  if (octets.length >= 3 &&
      octets[0] == 0xFF &&
      octets[1] == 0xD8 &&
      octets[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (octets.length >= 4 &&
      octets[0] == 0x89 &&
      octets[1] == 0x50 &&
      octets[2] == 0x4E &&
      octets[3] == 0x47) {
    return 'image/png';
  }
  if (octets.length >= 12 &&
      octets[0] == 0x52 &&
      octets[1] == 0x49 &&
      octets[2] == 0x46 &&
      octets[3] == 0x46 &&
      octets[8] == 0x57 &&
      octets[9] == 0x45 &&
      octets[10] == 0x42 &&
      octets[11] == 0x50) {
    return 'image/webp';
  }
  final bas = nom.toLowerCase();
  if (bas.endsWith('.png')) return 'image/png';
  if (bas.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

/// Version masquée affichable à l'écran sans exposer le secret.
String masquerCleGemini(String? cle) {
  final propre = cle?.trim() ?? '';
  if (propre.isEmpty) return 'Aucune clé configurée';
  if (propre.length < 6) return 'Clé configurée';
  return 'Clé configurée (••••${propre.substring(propre.length - 4)})';
}

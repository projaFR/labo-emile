import 'dart:convert';
import '../models/lesson_model.dart';

/// Types d'exercices reconnus par cette version de l'application.
const Set<String> kTypesExercicesConnus = {
  'numericBlanks',
  'textQcm',
  'singleInput',
  'saisieMot',
  'vraiFaux',
  'ordre',
};

/// Résultat d'une analyse JSON de leçon (matière + modèle validé).
class LeconImportee {
  final String matiere;
  final LessonModel lecon;

  const LeconImportee(this.matiere, this.lecon);
}

/// Nettoie le texte collé ou renvoyé par une IA : supprime les balises
/// ```json / ``` et ne garde que ce qui se trouve entre le premier `{` et le
/// dernier `}`.
String nettoyerJsonLecon(String raw) {
  var s = raw.replaceAll(RegExp(r'```json\s*', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'```\s*'), '');
  final start = s.indexOf('{');
  final end = s.lastIndexOf('}');
  if (start != -1 && end != -1 && end > start) {
    s = s.substring(start, end + 1);
  }
  return s.trim();
}

/// Analyse et valide strictement le JSON d'une leçon.
/// Lance une [FormatException] avec un message en français en cas d'anomalie.
LeconImportee analyserJsonLecon(String rawText) {
  final propre = rawText.trim();
  if (propre.isEmpty) {
    throw const FormatException('❌ Le texte JSON est vide.');
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(nettoyerJsonLecon(propre));
  } catch (_) {
    throw const FormatException(
      '❌ Code JSON mal copié ou invalide. Vérifie la syntaxe.',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException(
      '❌ Code JSON mal copié ou invalide. Vérifie la syntaxe.',
    );
  }

  final rawTitre = decoded['titre'];
  if (rawTitre is! String || rawTitre.trim().isEmpty) {
    throw const FormatException("❌ Le champ 'titre' est obligatoire.");
  }
  final titre = rawTitre.trim();

  final rawMatiere = decoded['matiere'];
  final matiere = (rawMatiere is String && rawMatiere.trim().isNotEmpty)
      ? rawMatiere.trim()
      : 'Mathématiques';

  final rawSucces = decoded['succes'];
  final succes = (rawSucces is String && rawSucces.trim().isNotEmpty)
      ? rawSucces.trim()
      : null;

  // 1. Extraction des Astuces (Flashcards)
  final astucesRaw = decoded['astuces'] ?? const [];
  if (astucesRaw is! List) {
    throw const FormatException("❌ Le champ 'astuces' doit être une liste.");
  }
  final importedCards = <FlashcardModel>[];
  for (var i = 0; i < astucesRaw.length; i++) {
    final item = astucesRaw[i];
    if (item is! Map ||
        item['question'] is! String ||
        item['reponse'] is! String) {
      throw FormatException(
        "❌ L'astuce n°${i + 1} est incomplète (question ou réponse manquante).",
      );
    }
    importedCards.add(
      FlashcardModel(
        question: item['question'] as String,
        reponse: item['reponse'] as String,
      ),
    );
  }

  // 2. Extraction des Exercices
  final exercicesRaw = decoded['exercices'] ?? const [];
  if (exercicesRaw is! List) {
    throw const FormatException("❌ Le champ 'exercices' doit être une liste.");
  }
  final importedExercises = <ExerciseModel>[];
  for (var i = 0; i < exercicesRaw.length; i++) {
    final item = exercicesRaw[i];
    if (item is! Map || item['question'] is! String) {
      throw FormatException(
        "❌ L'exercice n°${i + 1} n'a pas de 'question'.",
      );
    }
    final question = item['question'] as String;
    final nbTrous = question.split('[?]').length - 1;

    final rawOptions = item['options'];
    if (rawOptions != null && rawOptions is! List) {
      throw FormatException(
        "❌ Exercice n°${i + 1} : 'options' doit être une liste.",
      );
    }
    final optionsList = rawOptions == null
        ? <String>[]
        : [for (final o in rawOptions) o.toString()];

    final rawMultiples = item['reponsesMultiples'];
    if (rawMultiples != null && rawMultiples is! List) {
      throw FormatException(
        "❌ Exercice n°${i + 1} : 'reponsesMultiples' doit être une liste.",
      );
    }
    final reponsesMultiples = rawMultiples == null
        ? <String>[]
        : [for (final r in rawMultiples) r.toString()];

    final rawTypePre = item['type'];
    final estOrdre = rawTypePre is String && rawTypePre.trim() == 'ordre';

    if (estOrdre) {
      if (reponsesMultiples.length < 2) {
        throw FormatException(
          "❌ Exercice n°${i + 1} : un exercice 'ordre' doit avoir au moins "
          "2 éléments dans 'reponsesMultiples'.",
        );
      }
    } else {
      if (nbTrous > 1 && reponsesMultiples.isEmpty) {
        final isQcmSingleHole = optionsList.isNotEmpty && nbTrous == 1;
        if (!isQcmSingleHole) {
          throw FormatException(
            "❌ Exercice n°${i + 1} : $nbTrous trous [?] détectés "
            "mais 'reponsesMultiples' est absent ou vide.\n"
            "Corrige le JSON ou relance la génération.",
          );
        }
      }

      if (reponsesMultiples.isNotEmpty && reponsesMultiples.length != nbTrous) {
        throw FormatException(
          "❌ Exercice n°${i + 1} : $nbTrous trous [?] détectés "
          "mais ${reponsesMultiples.length} réponse(s) dans 'reponsesMultiples'.\n"
          "Le nombre doit être identique.",
        );
      }
    }

    final rawConsigne = item['consigne'];
    final consigne = (rawConsigne is String && rawConsigne.trim().isNotEmpty)
        ? rawConsigne
        : 'Trouve la bonne réponse';

    final rawAstuce = item['astuceErreur'];
    final astuceErreur = rawAstuce is String ? rawAstuce : '';

    final rawType = item['type'];
    String? typeExplicite;
    if (rawType != null) {
      if (rawType is! String || !kTypesExercicesConnus.contains(rawType.trim())) {
        throw FormatException(
          "❌ Exercice n°${i + 1} : type '$rawType' inconnu. "
          "Mets l'appli à jour pour utiliser ce nouveau type d'exercice.",
        );
      }
      typeExplicite = rawType.trim();
    }

    final rawAcceptees = item['reponsesAcceptees'];
    if (rawAcceptees != null && rawAcceptees is! List) {
      throw FormatException(
        "❌ Exercice n°${i + 1} : 'reponsesAcceptees' doit être une liste.",
      );
    }
    final reponsesAcceptees = rawAcceptees == null
        ? const <String>[]
        : [for (final r in rawAcceptees) r.toString()];

    final rawExplication = item['explication'];
    final explication =
        (rawExplication is String && rawExplication.trim().isNotEmpty)
            ? rawExplication.trim()
            : null;

    importedExercises.add(
      ExerciseModel(
        question: question,
        consigne: consigne,
        reponseAttendue: item['reponseAttendue']?.toString() ?? '',
        reponsesMultiples: reponsesMultiples,
        astuceErreur: astuceErreur,
        options: optionsList,
        typeExplicite: typeExplicite,
        reponsesAcceptees: reponsesAcceptees,
        explication: explication,
      ),
    );
  }

  // 3. Extraction du Défi Chrono (Quiz)
  final quizRaw = decoded['quiz'] ?? const [];
  if (quizRaw is! List) {
    throw const FormatException("❌ Le champ 'quiz' doit être une liste.");
  }
  final importedQuiz = <QuizModel>[];
  for (var i = 0; i < quizRaw.length; i++) {
    final item = quizRaw[i];
    if (item is! Map ||
        item['question'] is! String ||
        item['options'] is! List ||
        item['indexCorrect'] is! int) {
      throw FormatException(
        "❌ La question de quiz n°${i + 1} est incomplète.",
      );
    }
    final options = [for (final o in (item['options'] as List)) o.toString()];
    final indexCorrect = item['indexCorrect'] as int;
    if (options.isEmpty || indexCorrect < 0 || indexCorrect >= options.length) {
      throw FormatException(
        "❌ La question de quiz n°${i + 1} a un indexCorrect invalide.",
      );
    }
    importedQuiz.add(
      QuizModel(
        question: item['question'] as String,
        options: options,
        indexCorrect: indexCorrect,
      ),
    );
  }

  if (importedCards.isEmpty &&
      importedExercises.isEmpty &&
      importedQuiz.isEmpty) {
    throw const FormatException(
      '❌ La leçon ne contient ni astuce, ni exercice, ni quiz.',
    );
  }

  return LeconImportee(
    matiere,
    LessonModel(
      titre: titre,
      succes: succes,
      astuces: importedCards,
      exercices: importedExercises,
      quiz: importedQuiz,
    ),
  );
}

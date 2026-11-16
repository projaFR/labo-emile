import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ouvrir_lien.dart';
import '../theme.dart';
import '../models/lesson_model.dart';

/// Import d'une leçon (collage du JSON de l'IA). Une seule implémentation,
/// ouverte par « Ajouter une leçon » (après le code parent).
/// Le format JSON des leçons n'a PAS changé.
class ImportLeconView extends StatefulWidget {
  final void Function(String matiere, LessonModel lecon) onLessonImported;

  const ImportLeconView({super.key, required this.onLessonImported});

  @override
  State<ImportLeconView> createState() => _ImportLeconViewState();
}

class _ImportLeconViewState extends State<ImportLeconView> {
  final _jsonController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _openClaude() async {
    await ouvrirLien(
      'https://claude.ai/new?q=Le%C3%A7on%20pour%20le%20Labo%20d%27%C3%89mile',
    );
  }

  Future<void> _pasteAndImport() async {
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {
      setState(() {
        _errorMessage =
            '⚠️ Le navigateur a bloqué l\'accès au presse-papiers. '
            'Colle le texte manuellement dans le champ ci-dessous.';
      });
      return;
    }
    final text = data?.text ?? '';
    if (text.isEmpty) {
      setState(() {
        _errorMessage =
            '⚠️ Le presse-papiers est vide. Copie d\'abord le JSON '
            'depuis Claude, puis réessaie.';
      });
      return;
    }
    _jsonController.text = text;
    _importJsonLesson();
  }

  /// Nettoie le texte collé : supprime les balises ```json / ```,
  /// et tout ce qui précède le premier { ou suit le dernier }.
  String _cleanJson(String raw) {
    // Enlever les balises markdown ```json ... ``` ou ``` ... ```
    String s = raw.replaceAll(RegExp(r'```json\s*', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'```\s*'), '');
    // Garder uniquement ce qui est entre le premier { et le dernier }
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      s = s.substring(start, end + 1);
    }
    return s.trim();
  }

  void _importJsonLesson() {
    setState(() => _errorMessage = null);
    final rawText = _jsonController.text.trim();
    if (rawText.isEmpty) return;

    try {
      final Map<String, dynamic> parsedJson = jsonDecode(_cleanJson(rawText));

      // ✅ FIX : Validation explicite des champs obligatoires avant de continuer.
      //          Une leçon sans titre ou sans contenu ne s'importe pas silencieusement.
      if (parsedJson['titre'] == null ||
          (parsedJson['titre'] as String).trim().isEmpty) {
        setState(() => _errorMessage = "❌ Le champ 'titre' est obligatoire.");
        return;
      }

      final String matiere = parsedJson['matiere'] ?? 'Mathématiques';
      final String titre = (parsedJson['titre'] as String).trim();

      // 1. Extraction des Astuces (Flashcards)
      final List<dynamic> astucesRaw = parsedJson['astuces'] ?? [];
      List<FlashcardModel> importedCards = [];
      for (int i = 0; i < astucesRaw.length; i++) {
        final item = astucesRaw[i];
        // ✅ FIX : On signale les champs manquants au lieu de les ignorer
        if (item['question'] == null || item['reponse'] == null) {
          setState(
            () => _errorMessage =
                "❌ L'astuce n°${i + 1} est incomplète (question ou réponse manquante).",
          );
          return;
        }
        importedCards.add(
          FlashcardModel(
            question: item['question'] as String,
            reponse: item['reponse'] as String,
          ),
        );
      }

      // 2. Extraction des Exercices
      final List<dynamic> exercicesRaw = parsedJson['exercices'] ?? [];
      List<ExerciseModel> importedExercises = [];
      for (int i = 0; i < exercicesRaw.length; i++) {
        final item = exercicesRaw[i];
        if (item['question'] == null) {
          setState(
            () => _errorMessage =
                "❌ L'exercice n°${i + 1} n'a pas de 'question'.",
          );
          return;
        }

        final String question = item['question'] as String;
        final int nbTrous = question.split('[?]').length - 1;

        List<String> optionsList = [];
        if (item['options'] != null) {
          optionsList = List<String>.from(item['options']);
        }

        List<String> reponsesMultiples = [];
        if (item['reponsesMultiples'] != null) {
          reponsesMultiples = List<String>.from(item['reponsesMultiples']);
        }

        // ✅ Pour TOUS les types (QCM ou trous numériques) :
        // chaque [?] correspond maintenant à une case visible dans la question.
        // La règle s'applique donc universellement.
        if (nbTrous > 1 && reponsesMultiples.isEmpty) {
          // QCM à trou unique : reponseAttendue suffit, pas d'erreur
          final bool isQcmSingleHole = optionsList.isNotEmpty && nbTrous == 1;
          if (!isQcmSingleHole) {
            setState(
              () => _errorMessage =
                  "❌ Exercice n°${i + 1} : $nbTrous trous [?] détectés "
                  "mais 'reponsesMultiples' est absent ou vide.\n"
                  "Corrige le JSON ou relance la génération.",
            );
            return;
          }
        }

        if (reponsesMultiples.isNotEmpty &&
            reponsesMultiples.length != nbTrous) {
          setState(
            () => _errorMessage =
                "❌ Exercice n°${i + 1} : $nbTrous trous [?] détectés "
                "mais ${reponsesMultiples.length} réponse(s) dans 'reponsesMultiples'.\n"
                "Le nombre doit être identique.",
          );
          return;
        }

        importedExercises.add(
          ExerciseModel(
            question: question,
            consigne: item['consigne'] ?? 'Trouve la bonne réponse',
            reponseAttendue: item['reponseAttendue']?.toString() ?? '',
            reponsesMultiples: reponsesMultiples,
            astuceErreur: item['astuceErreur'] ?? '',
            options: optionsList,
          ),
        );
      }

      // 3. Extraction du Défi Chrono (Quiz)
      final List<dynamic> quizRaw = parsedJson['quiz'] ?? [];
      List<QuizModel> importedQuiz = [];
      for (int i = 0; i < quizRaw.length; i++) {
        final item = quizRaw[i];
        if (item['question'] == null ||
            item['options'] == null ||
            item['indexCorrect'] == null) {
          setState(
            () => _errorMessage =
                "❌ La question de quiz n°${i + 1} est incomplète.",
          );
          return;
        }
        importedQuiz.add(
          QuizModel(
            question: item['question'] as String,
            options: List<String>.from(item['options']),
            indexCorrect: item['indexCorrect'] as int,
          ),
        );
      }

      final newLesson = LessonModel(
        titre: titre,
        astuces: importedCards,
        exercices: importedExercises,
        quiz: importedQuiz,
      );

      widget.onLessonImported(matiere, newLesson);
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMessage =
            "❌ Code JSON mal copié ou invalide. Vérifie la syntaxe.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text("📸", style: TextStyle(fontSize: 24)),
                SizedBox(width: 8),
                Text(
                  "Ajouter une leçon",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: LaboPalette.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Bouton "Créer une leçon avec Claude"
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openClaude,
                icon: const Icon(Icons.auto_awesome, color: Colors.deepPurple),
                label: const Text(
                  'Créer une leçon avec Claude ✨',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.deepPurple),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _jsonController,
              maxLines: 5,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Colle le code JSON de Claude ici...',
                border: const OutlineInputBorder(),
                fillColor: Colors.grey.shade50,
                filled: true,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: _errorMessage!.startsWith('⚠️')
                      ? Colors.orange.shade800
                      : LaboPalette.rouge,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 10),
            // Boutons côte à côte : Coller&importer  |  Analyser&Activer
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _pasteAndImport,
                      icon: const Icon(Icons.content_paste),
                      label: const Text(
                        'Coller et importer',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: LaboShape.card,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _importJsonLesson,
                      icon: const Icon(Icons.download_done),
                      label: const Text(
                        'Analyser 🚀',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LaboPalette.encre,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: LaboShape.card,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

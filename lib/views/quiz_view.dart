import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../logic/parcours_logic.dart';
import '../logic/seance_logic.dart';
import '../models/lesson_model.dart';
import '../logic/memoire.dart';
import '../services/memoire_service.dart';
import '../services/questions_masquees_service.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';

class QuizView extends StatefulWidget {
  final LessonModel lesson;
  final Function(int) onSuccess;
  final VoidCallback onFailure;
  final VoidCallback onPerfectQuiz;

  /// Mode « Révision du jour » : une seule question, sans chrono ni
  /// diamants ; appelée quand on touche « SUIVANT ».
  final VoidCallback? surFin;

  /// Mode « parcours » : appelée une fois à la fin du défi, avec le résultat ;
  /// la vue n'affiche alors pas son propre écran de fin.
  final void Function(ResultatEtape)? surResultat;

  const QuizView({
    super.key,
    required this.lesson,
    required this.onSuccess,
    required this.onFailure,
    required this.onPerfectQuiz,
    this.surFin,
    this.surResultat,
  });

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  int _currentIndex = 0;
  int _timeLeft = 30;
  int _limit = 30; // temps par question (0 = sans chrono), réglé par le parent
  bool _timedOut = false;
  late MancheQuiz _manche;
  Timer? _timer;
  bool _isSubmitted = false;
  int _selectedOptionIndex = -1;
  int _score = 0;
  int _lastGain = 0;
  int _nbPremier = 0; // résultats du défi, pour le parcours
  int _nbDeuxieme = 0; // temps écoulé : noté comme un 2e essai (cf. mémoire)
  final List<String> _ratees = [];
  bool _resultatEnvoye = false;

  // ✅ Ordre aléatoire des questions et des options
  List<QuizModel> _shuffledQuiz = [];

  @override
  void initState() {
    super.initState();
    _limit = widget.surFin != null ? 0 : SettingsService().chronoSecondes;
    _manche = MancheQuiz(_limit);
    _shuffleQuiz();
    _startQuestion();
  }

  void _shuffleQuiz() {
    // Mélange les questions (en excluant celles masquées par le parent)
    final source = widget.surFin != null
        ? widget.lesson.quiz
        : widget.lesson.quiz.where((q) {
            final cle = cleQuestion(
              widget.lesson.titre,
              TypeQuestion.quiz,
              q.question,
            );
            return !QuestionsMasqueesService().estMasquee(cle);
          }).toList();
    final shuffled = List<QuizModel>.from(source)..shuffle(Random());
    // Pour chaque question, mélange aussi les options en gardant indexCorrect sync
    _shuffledQuiz = shuffled.map((q) {
      final List<MapEntry<int, String>> indexed = q.options
          .asMap()
          .entries
          .toList()
        ..shuffle(Random());
      final List<String> newOptions = indexed.map((e) => e.value).toList();
      final int newCorrectIndex = indexed.indexWhere((e) => e.key == q.indexCorrect);
      return QuizModel(
        question: q.question,
        options: newOptions,
        indexCorrect: newCorrectIndex,
      );
    }).toList();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startQuestion() {
    _timeLeft = _limit;
    _isSubmitted = false;
    _timedOut = false;
    _lastGain = 0;
    _selectedOptionIndex = -1;
    _timer?.cancel();
    if (_limit > 0) _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        _timeOver();
      }
    });
  }

  /// Temps écoulé : ce n'est PAS une faute. On montre la bonne réponse
  /// (en douceur) et on passe à la suite, sans toucher au combo.
  void _timeOver() {
    _noter(Resultat.deuxiemeEssai);
    setState(() {
      _isSubmitted = true;
      _timedOut = true;
      _manche.tempsEcoule();
    });
  }

  void _validateSelection(int index, QuizModel currentQuiz) {
    if (_isSubmitted) return;
    _timer?.cancel();

    final bool isCorrect = (index == currentQuiz.indexCorrect);
    _noter(isCorrect ? Resultat.premierCoup : Resultat.rate);

    setState(() {
      _selectedOptionIndex = index;
      _isSubmitted = true;
      if (isCorrect) {
        SoundService().playSuccess();
        SoundService().hapticSuccess();
        _score++;
        // Les diamants sont versés tout de suite : rien n'est perdu si on
        // quitte le défi en cours de route.
        _lastGain = _manche.repondreJuste(_timeLeft);
        widget.onSuccess(_lastGain);
      } else {
        SoundService().playError();
        SoundService().hapticError();
        _manche.repondreFaux();
        widget.onFailure();
      }
    });
  }

  /// Mémoire par question : la question affichée est celle de la liste mélangée.
  void _noter(Resultat r) {
    if (r == Resultat.premierCoup) {
      _nbPremier++;
    } else if (r == Resultat.deuxiemeEssai) {
      _nbDeuxieme++;
    } else {
      _ratees.add(texteCourt(_shuffledQuiz[_currentIndex].question));
    }
    MemoireService().enregistrer(
      cleQuestion(
        widget.lesson.titre,
        TypeQuestion.quiz,
        _shuffledQuiz[_currentIndex].question,
      ),
      r,
    );
  }

  void _nextQuestion() {
    if (widget.surFin != null) {
      widget.surFin!();
      return;
    }
    setState(() {
      _currentIndex++;
      if (_currentIndex < _shuffledQuiz.length) {
        _startQuestion();
      } else {
        final etoile = _manche.etoile(_shuffledQuiz.length);
        if (etoile) {
          SoundService().playPerfect();
          widget.onPerfectQuiz();
        }
        _envoyerResultat(etoile);
      }
    });
  }

  /// Mode parcours : remonte le résultat une seule fois, hors construction.
  void _envoyerResultat(bool etoile) {
    final cb = widget.surResultat;
    if (cb == null || _resultatEnvoye) return;
    _resultatEnvoye = true;
    final r = ResultatEtape(
      premierCoup: _nbPremier,
      deuxiemeEssai: _nbDeuxieme,
      rates: _ratees.length,
      etoile: etoile,
      aRetravailler: List.of(_ratees),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cb(r);
    });
  }

  void _restartQuiz() {
    _nbPremier = 0;
    _nbDeuxieme = 0;
    _ratees.clear();
    _resultatEnvoye = false;
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _limit = SettingsService().chronoSecondes;
      _manche = MancheQuiz(_limit);
      _shuffleQuiz();
      _startQuestion();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_shuffledQuiz.isEmpty) {
      return const Center(
        child: Text("🏆 Pas de Défi Chrono configuré pour cette leçon."),
      );
    }

    if (_currentIndex >= _shuffledQuiz.length) {
      if (widget.surResultat != null) return const SizedBox.shrink();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "🏁 Défi Terminé !",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: LaboPalette.encre,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Score final : $_score / ${_shuffledQuiz.length}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _score == _shuffledQuiz.length
                    ? "👑 Parcours parfait ! Étoile obtenue ! (+5 💎)"
                    : "Pas encore parfait. Réessaie pour l'étoile, tu progresses !",
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _restartQuiz,
                child: const Text("Recommencer le défi"),
              ),
            ],
          ),
        ),
      );
    }

    final currentQuiz = _shuffledQuiz[_currentIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availH = constraints.maxHeight;
        final bool isCompact = availH < 500;
        final double outerPad = isCompact ? 10.0 : 16.0;
        final double gap = isCompact ? 10.0 : 16.0;
        final double cardPad = isCompact ? 12.0 : 20.0;
        final double questionFontSize = isCompact ? 15.0 : 18.0;
        final double btnH = isCompact ? 42.0 : 52.0;
        final double btnSpacing = isCompact ? 6.0 : 10.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(outerPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (widget.surFin == null)
                  Text(
                    "Question ${_currentIndex + 1} / ${_shuffledQuiz.length}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: LaboPalette.muted,
                    ),
                  ),
                  if (_limit > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: LaboPalette.warn,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "⏳ $_timeLeft s",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: gap),
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(cardPad),
                  child: Text(
                    currentQuiz.question,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: questionFontSize,
                      fontWeight: FontWeight.bold,
                      color: LaboPalette.ink,
                    ),
                  ),
                ),
              ),
              SizedBox(height: gap),
              ...List.generate(currentQuiz.options.length, (index) {
                final option = currentQuiz.options[index];
                final bool isCorrectOption = (index == currentQuiz.indexCorrect);
                final bool isThisSelected = (index == _selectedOptionIndex);
                Color btnColor = Colors.white;
                Color textColor = Colors.black87;

                if (_isSubmitted) {
                  if (isCorrectOption) {
                    btnColor = Colors.green.shade100;
                    textColor = Colors.green.shade900;
                  } else if (isThisSelected) {
                    btnColor = Colors.amber.shade100;
                    textColor = Colors.brown.shade900;
                  }
                }

                return Padding(
                  padding: EdgeInsets.only(bottom: btnSpacing),
                  child: SizedBox(
                    height: btnH,
                    child: ElevatedButton(
                      onPressed: _isSubmitted
                          ? null
                          : () => _validateSelection(index, currentQuiz),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnColor,
                        side: BorderSide(
                          color: _isSubmitted && isCorrectOption
                              ? LaboPalette.good
                              : Colors.black12,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: LaboShape.card,
                        ),
                      ),
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              if (_isSubmitted) ...[
                Builder(builder: (context) {
                  final bool ok = _selectedOptionIndex == currentQuiz.indexCorrect;
                  final String msg = ok
                      ? (widget.surFin != null
                            ? "✅ Bonne réponse !"
                            : _lastGain >= 2
                            ? "⚡ Bonus rapidité ! (+2 💎)"
                            : "✅ Bonne réponse ! (+1 💎)")
                      : _timedOut
                      ? "⏳ Temps écoulé, pas grave ! La bonne réponse est en vert."
                      : "Ce n'est pas ça. La bonne réponse est en vert.";
                  return Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: ok ? Colors.green.shade50 : Colors.amber.shade50,
                      borderRadius: LaboShape.button,
                    ),
                    child: Text(
                      msg,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ok ? Colors.green.shade800 : Colors.brown.shade800,
                        fontSize: 13,
                      ),
                    ),
                  );
                }),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _nextQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LaboPalette.encre,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: LaboShape.card,
                      ),
                    ),
                    child: const Text(
                      "QUESTION SUIVANTE ➡️",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
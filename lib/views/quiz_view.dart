import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lesson_model.dart';
import '../services/sound_service.dart';

class QuizView extends StatefulWidget {
  final LessonModel lesson;
  final Function(int) onSuccess;
  final VoidCallback onFailure;
  final VoidCallback onPerfectQuiz;

  const QuizView({
    super.key,
    required this.lesson,
    required this.onSuccess,
    required this.onFailure,
    required this.onPerfectQuiz,
  });

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  int _currentIndex = 0;
  int _timeLeft = 15;
  Timer? _timer;
  bool _isSubmitted = false;
  int _selectedOptionIndex = -1;
  int _score = 0;

  int _correctAnswers = 0;
  int _pendingDiamonds = 0;

  // ✅ Ordre aléatoire des questions et des options
  List<QuizModel> _shuffledQuiz = [];

  @override
  void initState() {
    super.initState();
    _shuffleQuiz();
    _startQuestion();
  }

  void _shuffleQuiz() {
    // Mélange les questions
    final shuffled = List<QuizModel>.from(widget.lesson.quiz)..shuffle(Random());
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
    _timeLeft = 15;
    _isSubmitted = false;
    _selectedOptionIndex = -1;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        _timeOver();
      }
    });
  }

  void _timeOver() {
    setState(() {
      _isSubmitted = true;
      SoundService().playError();
      HapticFeedback.heavyImpact();
      widget.onFailure();
    });
  }

  void _validateSelection(int index, QuizModel currentQuiz) {
    if (_isSubmitted) return;
    _timer?.cancel();

    final bool isCorrect = (index == currentQuiz.indexCorrect);

    setState(() {
      _selectedOptionIndex = index;
      _isSubmitted = true;
      if (isCorrect) {
        SoundService().playSuccess();
        HapticFeedback.lightImpact();
        _score++;
        _correctAnswers++;
        _pendingDiamonds += (_timeLeft > 10) ? 2 : 1;
      } else {
        SoundService().playError();
        HapticFeedback.heavyImpact();
        widget.onFailure();
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      _currentIndex++;
      if (_currentIndex < _shuffledQuiz.length) {
        _startQuestion();
      } else {
        // ✅ FIX : C'est ici, à la fin, qu'on crédite TOUT d'un coup.
        //          Les diamants et l'étoile sont toujours cohérents.
        if (_pendingDiamonds > 0) {
          widget.onSuccess(_pendingDiamonds);
        }
        if (_correctAnswers == _shuffledQuiz.length) {
          SoundService().playPerfect();
          widget.onPerfectQuiz();
        }
      }
    });
  }

  void _restartQuiz() {
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _correctAnswers = 0;
      _pendingDiamonds = 0;
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
                  color: Colors.blue,
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
                    ? "👑 Course parfaite contre la montre ! Étoile obtenue ! (+5 💎)"
                    : "Tu as fait des erreurs. Réessaie à toute vitesse pour l'étoile !",
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                "Question ${_currentIndex + 1} / ${_shuffledQuiz.length}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _timeLeft <= 5 ? Colors.red : Colors.orange,
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
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                currentQuiz.question,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Options : taille fixe par bouton, plus de Expanded/ListView
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
                btnColor = Colors.red.shade100;
                textColor = Colors.red.shade900;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitted
                      ? null
                      : () => _validateSelection(index, currentQuiz),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnColor,
                    side: BorderSide(
                      color: _isSubmitted && isCorrectOption
                          ? Colors.green
                          : Colors.black12,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _selectedOptionIndex == currentQuiz.indexCorrect
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _selectedOptionIndex == currentQuiz.indexCorrect
                    ? (_timeLeft > 10
                          ? "⚡ BONUS RAPIDITÉ ACTIVÉ ! Double Diamant ! (+2 💎)"
                          : "✅ Bonne réponse ! (+1 💎)")
                    : "❌ Ce n'est pas la bonne réponse.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _selectedOptionIndex == currentQuiz.indexCorrect
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                  fontSize: 13,
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
  }
}
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../models/lesson_model.dart';
import '../widgets/confetti_couche.dart';
import 'exercise_view.dart';
import 'flashcards_view.dart';
import 'quiz_view.dart';

/// Écran de lecture d'une leçon (provisoire, le lot 2 en fera un parcours
/// guidé) : trois onglets Astuces / Entraînement / Défi chrono et un retour.
class LeconScreen extends StatefulWidget {
  final LessonModel lesson;
  final int etapeInitiale;
  final ConfettiController confetti;

  /// Étoiles actuelles de la leçon [astuces, entraînement, chrono].
  final List<bool> Function() etoiles;
  final VoidCallback onDiamondEarned;
  final void Function(int indexEtoile) onEtoile;
  final void Function(int gain) onSuccess;
  final VoidCallback onFailure;

  const LeconScreen({
    super.key,
    required this.lesson,
    required this.etapeInitiale,
    required this.confetti,
    required this.etoiles,
    required this.onDiamondEarned,
    required this.onEtoile,
    required this.onSuccess,
    required this.onFailure,
  });

  @override
  State<LeconScreen> createState() => _LeconScreenState();
}

class _LeconScreenState extends State<LeconScreen> {
  late int _etape = widget.etapeInitiale.clamp(0, 2);

  void _etoile(int i) {
    widget.onEtoile(i);
    if (mounted) setState(() {});
  }

  Widget _contenu() {
    switch (_etape) {
      case 0:
        return FlashcardsView(
          lesson: widget.lesson,
          onDiamondEarned: widget.onDiamondEarned,
          onLessonCompleted: () => _etoile(0),
        );
      case 1:
        return ExerciseView(
          lesson: widget.lesson,
          onSuccess: () => widget.onSuccess(1),
          onFailure: widget.onFailure,
          onPerfectScore: () => _etoile(1),
        );
      default:
        return QuizView(
          lesson: widget.lesson,
          onSuccess: (gain) => widget.onSuccess(gain),
          onFailure: widget.onFailure,
          onPerfectQuiz: () => _etoile(2),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stars = widget.etoiles();
    final parfaite = stars.every((s) => s);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.lesson.titre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 36,
                    color: Colors.orange.shade50,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          parfaite ? "👑 Leçon maîtrisée" : "✨ Étoiles de la leçon",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        Text(
                          "${stars[0] ? "🃏⭐" : "🃏☆"}  "
                          "${stars[1] ? "🎯⭐" : "🎯☆"}  "
                          "${stars[2] ? "⏱️⭐" : "⏱️☆"}",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _contenu()),
                ],
              ),
            ),
          ),
          ConfettiCouche(controller: widget.confetti),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _etape,
        selectedItemColor: Colors.blue[700],
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (i) => setState(() => _etape = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.style, size: 22),
            label: 'Astuces',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center, size: 22),
            label: 'Entraînement',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer, size: 22),
            label: 'Défi chrono',
          ),
        ],
      ),
    );
  }
}

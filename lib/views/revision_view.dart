import 'package:flutter/material.dart';
import '../theme.dart';
import '../logic/memoire.dart';
import '../models/lesson_model.dart';
import 'exercise_view.dart';
import 'flashcards_view.dart';
import 'quiz_view.dart';

/// « Révision du jour » : au plus 12 questions dues, de toutes les leçons,
/// les plus en retard d'abord. Réutilise les écrans des cartes, des exercices
/// et du quiz en mode « une seule question » (sans chrono ni diamant par
/// question : la récompense est fixe, une fois par jour, à la fin).
class RevisionView extends StatefulWidget {
  /// Questions à revoir (déjà triées et limitées).
  final List<RefQuestion> questions;

  /// Appelée une fois, à la fin : renvoie le nombre de diamants gagnés
  /// (0 si la récompense du jour a déjà été prise).
  final Future<int> Function() onTerminee;

  /// « Réviser quand même » : séance libre, sans diamants et sans appeler
  /// [onTerminee]. Les réponses comptent dans la mémoire comme d'habitude.
  final bool libre;

  const RevisionView({
    super.key,
    required this.questions,
    required this.onTerminee,
    this.libre = false,
  });

  @override
  State<RevisionView> createState() => _RevisionViewState();
}

class _RevisionViewState extends State<RevisionView> {
  int _i = 0;
  int? _diamants; // renseigné à la fin

  void _suite() {
    if (_i + 1 < widget.questions.length) {
      setState(() => _i++);
    } else {
      if (widget.libre) {
        _diamants = 0;
      } else {
        widget.onTerminee().then((d) {
          if (mounted) setState(() => _diamants = d);
        });
      }
      setState(() => _i = widget.questions.length);
    }
  }

  /// Leçon réduite à la seule question à réviser (même titre : la mémoire
  /// retrouve sa clé).
  LessonModel _miniLecon(RefQuestion r) {
    final l = r.lecon;
    return LessonModel(
      titre: l.titre,
      astuces: r.type == TypeQuestion.astuce ? [l.astuces[r.index]] : const [],
      exercices:
          r.type == TypeQuestion.exercice ? [l.exercices[r.index]] : const [],
      quiz: r.type == TypeQuestion.quiz ? [l.quiz[r.index]] : const [],
    );
  }

  Widget _message(String titre, String texte, {Widget? bas}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titre,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: LaboPalette.encre,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            texte,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Colors.black54),
          ),
          if (bas != null) ...[const SizedBox(height: 16), bas],
        ],
      ),
    ),
  );

  Widget _retour() => ElevatedButton(
    onPressed: () => Navigator.of(context).pop(),
    child: const Text('Retour à l\'accueil'),
  );

  Widget _corps() {
    final qs = widget.questions;
    if (qs.isEmpty) {
      return _message(
        '🎉 Rien à revoir aujourd\'hui !',
        'Tu as tout révisé, bravo ! Reviens demain : les questions '
            'reviennent au bon moment pour que tu les retiennes longtemps.',
        bas: _retour(),
      );
    }
    if (_i >= qs.length) {
      if (widget.libre) {
        return _message(
          '🏆 Séance terminée',
          'Bien joué, tu as tout repassé en revue. '
              'Pas de diamants cette fois : pour le plaisir.',
          bas: _retour(),
        );
      }
      return _message(
        '🏆 Révision du jour terminée !',
        _diamants == null
            ? '…'
            : (_diamants! > 0
                  ? 'Bravo ! +$_diamants 💎\nÀ demain pour la suite.'
                  : 'Bravo ! Tu as déjà reçu tes diamants aujourd\'hui.\n'
                        'À demain pour la suite.'),
        bas: _retour(),
      );
    }

    final r = qs[_i];
    final mini = _miniLecon(r);
    final cle = ValueKey('${r.cle}_$_i');
    final Widget ecran;
    final String etiquette;
    switch (r.type) {
      case TypeQuestion.astuce:
        etiquette = '🃏 Astuce';
        ecran = FlashcardsView(
          key: cle,
          lesson: mini,
          onDiamondEarned: () {},
          onLessonCompleted: () {},
          surFin: _suite,
        );
      case TypeQuestion.exercice:
        etiquette = '🎯 Exercice';
        ecran = ExerciseView(
          key: cle,
          lesson: mini,
          onSuccess: () {},
          onFailure: () {},
          onPerfectScore: () {},
          surFin: _suite,
        );
      case TypeQuestion.quiz:
        etiquette = '⏱️ Question';
        ecran = QuizView(
          key: cle,
          lesson: mini,
          onSuccess: (_) {},
          onFailure: () {},
          onPerfectQuiz: () {},
          surFin: _suite,
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: LaboPalette.paper,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Question ${_i + 1} / ${qs.length}  ·  $etiquette  ·  ${r.lecon.titre}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: LaboPalette.muted,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _i / qs.length,
                  minHeight: 5,
                  backgroundColor: LaboPalette.line,
                  valueColor: const AlwaysStoppedAnimation(LaboPalette.encre),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: ecran),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.libre ? '🔁 Réviser quand même' : '🔁 Révision du jour',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SafeArea(child: _corps()),
    );
  }
}

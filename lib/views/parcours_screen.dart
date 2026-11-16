import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../logic/parcours_logic.dart';
import '../models/lesson_model.dart';
import '../theme.dart';
import '../widgets/confetti_couche.dart';
import 'exercise_view.dart';
import 'fin_lecon_view.dart';
import 'flashcards_view.dart';
import 'quiz_view.dart';

enum _Phase { etape, transition, recap }

/// Parcours guidé d'une leçon : Astuces, Entraînement, Défi chrono, dans
/// l'ordre, avec un écran de transition entre deux étapes puis un récap.
/// Avec une seule étape dans [etapes], c'est une étape isolée (récap court).
class ParcoursScreen extends StatefulWidget {
  final LessonModel lesson;

  /// Étapes à jouer (indices 0, 1, 2), dans l'ordre.
  final List<int> etapes;

  /// Position de départ dans [etapes].
  final int depart;

  /// Vrai pour le parcours complet de la leçon, faux pour une étape isolée.
  final bool complet;
  final ConfettiController confetti;

  /// Étoiles actuelles de la leçon [astuces, entraînement, chrono].
  final List<bool> Function() etoiles;

  /// Diamants de l'enfant (pour compter ceux gagnés pendant le passage).
  final ValueListenable<int> diamants;
  final VoidCallback onDiamondEarned;
  final void Function(int indexEtoile) onEtoile;
  final void Function(int gain) onSuccess;
  final VoidCallback onFailure;

  /// Appelée par « Retour à Aujourd'hui » (en plus de fermer le parcours).
  final VoidCallback onRetourAccueil;

  const ParcoursScreen({
    super.key,
    required this.lesson,
    required this.etapes,
    required this.depart,
    required this.complet,
    required this.confetti,
    required this.etoiles,
    required this.diamants,
    required this.onDiamondEarned,
    required this.onEtoile,
    required this.onSuccess,
    required this.onFailure,
    required this.onRetourAccueil,
  });

  @override
  State<ParcoursScreen> createState() => _ParcoursScreenState();
}

class _ParcoursScreenState extends State<ParcoursScreen> {
  late int _pos = widget.depart.clamp(0, widget.etapes.length - 1);
  _Phase _phase = _Phase.etape;
  int _gen = 0; // change à chaque nouvelle étape : repart d'une vue neuve
  final Map<int, ResultatEtape> _resultats = {};
  late List<bool> _etoilesAvant;
  late int _baseParcours;
  late int _baseEtape;

  int get _indice => widget.etapes[_pos];

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  void _initialiser() {
    _etoilesAvant = List.of(widget.etoiles());
    _baseParcours = widget.diamants.value;
    _baseEtape = _baseParcours;
  }

  void _etoile(int i) {
    widget.onEtoile(i);
    if (mounted) setState(() {});
  }

  void _surResultat(ResultatEtape r) {
    if (!mounted || _phase != _Phase.etape) return;
    setState(() {
      _resultats[_indice] = r;
      _phase = widget.complet && etapeSuivante(_pos, widget.etapes.length) != null
          ? _Phase.transition
          : _Phase.recap;
    });
    if (_phase == _Phase.recap) _surRecap();
  }

  void _surRecap() {
    if (etoilesRecap(_etoilesAvant, _resultats) >= 3 && widget.complet) {
      widget.confetti.play();
    }
  }

  void _passer() {
    final suivante = etapeSuivante(_pos, widget.etapes.length);
    setState(() {
      _resultats[_indice] = const ResultatEtape.passee();
      if (suivante != null) {
        _pos = suivante;
        _gen++;
        _baseEtape = widget.diamants.value;
      } else {
        _phase = _Phase.recap;
      }
    });
    if (_phase == _Phase.recap) _surRecap();
  }

  void _cestParti() {
    final suivante = etapeSuivante(_pos, widget.etapes.length);
    if (suivante == null) return;
    setState(() {
      final r = _resultats[_indice];
      if (r != null) {
        _resultats[_indice] = r.avecDiamants(
          widget.diamants.value - _baseEtape,
        );
      }
      _pos = suivante;
      _gen++;
      _phase = _Phase.etape;
      _baseEtape = widget.diamants.value;
    });
  }

  void _rejouer() {
    setState(() {
      _resultats.clear();
      _pos = 0;
      _gen++;
      _phase = _Phase.etape;
      _initialiser();
    });
  }

  Future<void> _quitter() async {
    final oui = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Quitter la leçon ?"),
        content: const Text("Tes diamants gagnés sont gardés."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Quitter"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Continuer la leçon"),
          ),
        ],
      ),
    );
    if (oui == true && mounted) Navigator.of(context).pop();
  }

  // ── Étape en cours ────────────────────────────────────────────────────────
  Widget _vueEtape() {
    final cle = ValueKey('$_gen-$_pos');
    switch (_indice) {
      case 0:
        return FlashcardsView(
          key: cle,
          lesson: widget.lesson,
          onDiamondEarned: widget.onDiamondEarned,
          onLessonCompleted: () => _etoile(0),
          surResultat: _surResultat,
        );
      case 1:
        return ExerciseView(
          key: cle,
          lesson: widget.lesson,
          onSuccess: () => widget.onSuccess(1),
          onFailure: widget.onFailure,
          onPerfectScore: () => _etoile(1),
          surResultat: _surResultat,
        );
      default:
        return QuizView(
          key: cle,
          lesson: widget.lesson,
          onSuccess: (gain) => widget.onSuccess(gain),
          onFailure: widget.onFailure,
          onPerfectQuiz: () => _etoile(2),
          surResultat: _surResultat,
        );
    }
  }

  Widget _corps() {
    switch (_phase) {
      case _Phase.etape:
        final dejaFaite = _indice < _etoilesAvant.length && _etoilesAvant[_indice];
        return Column(
          children: [
            if (dejaFaite)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _passer,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: LaboPalette.muted,
                  ),
                  child: const Text("Passer cette étape"),
                ),
              ),
            Expanded(child: _vueEtape()),
          ],
        );
      case _Phase.transition:
        return _Transition(
          key: ValueKey('t$_gen-$_pos'),
          numero: _pos + 1,
          resultat: _resultats[_indice]!,
          etoileAcquise: _resultats[_indice]!.etoile ||
              (_indice < _etoilesAvant.length && _etoilesAvant[_indice]),
          diamants: widget.diamants,
          baseDiamants: _baseEtape,
          prochaine: kNomsEtapes[widget.etapes[_pos + 1]],
          onSuite: _cestParti,
        );
      case _Phase.recap:
        return ValueListenableBuilder<int>(
          valueListenable: widget.diamants,
          builder: (_, d, _) {
            final recap = cumuler(_resultats.values);
            final etoiles = etoilesRecap(_etoilesAvant, _resultats);
            return FinLeconView(
              key: ValueKey('r$_gen'),
              leconComplete: widget.complet,
              nomEtape: kNomsEtapes[widget.etapes.first],
              etoiles: widget.complet
                  ? etoiles
                  : ((_resultats[_indice]?.etoile ?? false) ||
                            _etoilesAvant[_indice]
                        ? 1
                        : 0),
              etoilesMax: widget.complet ? 3 : 1,
              diamants: (d - _baseParcours).clamp(0, 1 << 30),
              recap: recap,
              message: messageEncouragement(
                widget.complet ? etoiles : (etoiles > 0 ? 2 : 0),
                graine: widget.lesson.titre.length + _gen,
              ),
              libelleRetour: widget.complet
                  ? "Retour à Aujourd'hui"
                  : "Retour à la leçon",
              onRetour: () {
                if (widget.complet) {
                  widget.onRetourAccueil();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                } else {
                  Navigator.of(context).pop();
                }
              },
              onRejouer: _rejouer,
            );
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.etapes.length;
    final fait = switch (_phase) {
      _Phase.etape => _pos,
      _Phase.transition => _pos + 1,
      _Phase.recap => total,
    };
    final enRecap = _phase == _Phase.recap;
    return PopScope(
      canPop: enRecap,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quitter();
      },
      child: Scaffold(
        backgroundColor: LaboPalette.paper,
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
          leading: IconButton(
            tooltip: "Retour",
            icon: const Icon(Icons.arrow_back),
            onPressed: enRecap ? () => Navigator.of(context).pop() : _quitter,
          ),
        ),
        body: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            enRecap
                                ? (widget.complet
                                      ? "Leçon terminée"
                                      : "Étape terminée")
                                : libelleEtape(_pos, total, _indice),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: LaboPalette.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: 0,
                              end: progressionParcours(fait, total),
                            ),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                            builder: (_, v, _) => ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: v,
                                minHeight: 10,
                                backgroundColor: Colors.blue.shade100,
                                valueColor: const AlwaysStoppedAnimation(
                                  LaboPalette.good,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _corps()),
                  ],
                ),
              ),
            ),
            ConfettiCouche(controller: widget.confetti),
          ],
        ),
      ),
    );
  }
}

/// Écran entre deux étapes : court et joyeux.
class _Transition extends StatelessWidget {
  final int numero;
  final ResultatEtape resultat;
  final bool etoileAcquise;
  final ValueListenable<int> diamants;
  final int baseDiamants;
  final String prochaine;
  final VoidCallback onSuite;

  const _Transition({
    super.key,
    required this.numero,
    required this.resultat,
    required this.etoileAcquise,
    required this.diamants,
    required this.baseDiamants,
    required this.prochaine,
    required this.onSuite,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: const Icon(
                Icons.check_circle,
                size: 96,
                color: LaboPalette.good,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Étape $numero terminée !",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: LaboPalette.ink,
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<int>(
              valueListenable: diamants,
              builder: (_, d, _) {
                final gain = (d - baseDiamants).clamp(0, 1 << 30);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.diamond, color: Colors.purple),
                    const SizedBox(width: 6),
                    Text(
                      "+$gain",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Icon(
                      etoileAcquise ? Icons.star : Icons.star_border,
                      color: etoileAcquise
                          ? LaboPalette.touche
                          : Colors.grey.shade400,
                      size: 30,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      etoileAcquise ? "Étoile gagnée" : "Pas d'étoile",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            Text(
              "Prochaine étape : $prochaine",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: LaboPalette.muted),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onSuite,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                backgroundColor: LaboPalette.encre,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                "C'est parti",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

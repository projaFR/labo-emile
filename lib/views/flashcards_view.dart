import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/lesson_model.dart';
import '../logic/memoire.dart';
import '../services/memoire_service.dart';
import '../services/sound_service.dart';

class FlashcardsView extends StatefulWidget {
  final LessonModel lesson;
  final VoidCallback onDiamondEarned;
  final VoidCallback onLessonCompleted;

  /// Mode « Révision du jour » : une seule carte, sans diamant ni étoile ;
  /// appelée dès que la carte est notée.
  final VoidCallback? surFin;

  const FlashcardsView({
    super.key,
    required this.lesson,
    required this.onDiamondEarned,
    required this.onLessonCompleted,
    this.surFin,
  });

  @override
  State<FlashcardsView> createState() => _FlashcardsViewState();
}

class _FlashcardsViewState extends State<FlashcardsView> {
  List<FlashcardModel> deck = [];
  bool showAnswer = false;
  bool _aRevoir = false; // au moins une carte notée « à revoir » dans ce tour

  @override
  void initState() {
    super.initState();
    _loadLessonDeck();
  }

  @override
  void didUpdateWidget(covariant FlashcardsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lesson != widget.lesson) {
      _loadLessonDeck();
    }
  }

  void _loadLessonDeck() {
    setState(() {
      // ✅ Ordre aléatoire à chaque chargement du paquet
      deck = List<FlashcardModel>.from(widget.lesson.astuces)..shuffle();
      showAnswer = false;
      _aRevoir = false;
    });
  }

  void handleResult(bool success) {
    if (deck.isEmpty) return;
    // Mémoire par question : « Maîtrisé » = bonne réponse du 1er coup,
    // « À revoir » = à refaire demain.
    MemoireService().enregistrer(
      cleQuestion(widget.lesson.titre, TypeQuestion.astuce, deck[0].question),
      success ? Resultat.premierCoup : Resultat.rate,
    );
    if (widget.surFin != null) {
      if (success) {
        SoundService().playSuccess();
        SoundService().hapticSuccess();
      }
      widget.surFin!();
      return;
    }
    setState(() {
      if (!success) {
        // « À revoir » n'est pas une faute : pas de son d'erreur.
        _aRevoir = true;
        SoundService().hapticSuccess();
        final failedCard = deck.removeAt(0);
        deck.add(failedCard);
      } else {
        // « Maîtrisé » est une auto-note : plus de diamant par carte.
        SoundService().playSuccess();
        SoundService().hapticSuccess();
        deck.removeAt(0);
      }
      showAnswer = false;

      if (deck.isEmpty) {
        // Paquet terminé : un diamant fixe, et l'étoile seulement si aucune
        // carte n'a été notée « à revoir » (comme le dit le README).
        widget.onDiamondEarned();
        if (!_aRevoir) {
          SoundService().playStar();
          widget.onLessonCompleted();
        }
      }
    });
  }

  Widget _buildGhostCardUI(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            // ✅ FIX : withOpacity à la place de withValues(alpha:) pour une
            //          compatibilité maximale avec toutes les versions Flutter.
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
    );
  }

  Widget _buildTiltedGhostCard(
    int index,
    Offset offset,
    double baseRotation,
    double width,
    double height,
  ) {
    double rotation = baseRotation + (0.02 * (index % 4 - 2));
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: rotation,
        child: _buildGhostCardUI(width, height),
      ),
    );
  }

  Widget _buildCardUI(bool isBack, double width, double height) {
    if (deck.isEmpty) return const SizedBox.shrink();
    final card = deck[0];

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            // ✅ FIX : withOpacity à la place de withValues(alpha:)
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        !isBack ? card.question : card.reponse,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: !isBack ? 24 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (!isBack) ...[
                        const SizedBox(height: 14),
                        const Text(
                          "🤔 Dis la réponse dans ta tête\navant de retourner la carte",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: LaboPalette.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            height: 55,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.black12)),
            ),
            child: !isBack
                ? InkWell(
                    onTap: () => setState(() => showAnswer = true),
                    child: const Center(
                      child: Text(
                        "VOIR LA SOLUTION 🔍",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: LaboPalette.encre,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => handleResult(false),
                          child: const Center(
                            child: Text(
                              "À REVOIR ❌",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: LaboPalette.rouge,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(width: 1, color: Colors.black12),
                      Expanded(
                        child: InkWell(
                          onTap: () => handleResult(true),
                          child: Center(
                            child: Text(
                              widget.surFin != null ? "JE SAVAIS ✅" : "MAÎTRISÉ ✅",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: LaboPalette.good,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (deck.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "🎉 Félicitations !",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: LaboPalette.good,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _aRevoir
                    ? "Paquet terminé ! (+1 💎)\nRefais-le sans « À revoir » pour gagner l'étoile ⭐"
                    : "Paquet terminé sans « À revoir » !\n⭐ Étoile et +1 💎",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadLessonDeck,
                child: const Text("Revoir le paquet"),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double cardWidth = (constraints.maxWidth * 0.85).clamp(280.0, 340.0);
        double cardHeight = (constraints.maxHeight * 0.70).clamp(320.0, 420.0);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.surFin == null)
            Text(
              "Cartes restantes : ${deck.length}",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: LaboPalette.muted,
              ),
            ),
            if (widget.surFin == null) const SizedBox(height: 10),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (deck.length > 1)
                    _buildTiltedGhostCard(
                      1,
                      const Offset(0, 6),
                      -0.04,
                      cardWidth,
                      cardHeight,
                    ),
                  if (deck.length > 2)
                    _buildTiltedGhostCard(
                      2,
                      const Offset(0, 12),
                      0.04,
                      cardWidth,
                      cardHeight,
                    ),
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: showAnswer ? 180 : 0),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, double angle, child) {
                      final isBack = angle >= 90;
                      return Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.002)
                          ..rotateY(angle * pi / 180),
                        alignment: Alignment.center,
                        child: isBack
                            ? Transform(
                                transform: Matrix4.identity()..rotateY(pi),
                                alignment: Alignment.center,
                                child: _buildCardUI(
                                  true,
                                  cardWidth,
                                  cardHeight,
                                ),
                              )
                            : _buildCardUI(false, cardWidth, cardHeight),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

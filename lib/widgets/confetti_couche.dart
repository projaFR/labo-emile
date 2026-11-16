import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Couche de confettis posée au-dessus d'un écran (dans un Stack).
class ConfettiCouche extends StatelessWidget {
  final ConfettiController controller;
  const ConfettiCouche({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConfettiWidget(
      confettiController: controller,
      blastDirectionality: BlastDirectionality.explosive,
      numberOfParticles: 30,
      gravity: 0.2,
      emissionFrequency: 0.05,
      colors: const [
        LaboPalette.encre,
        LaboPalette.warn,
        LaboPalette.good,
        Colors.yellow,
        Colors.purple,
        LaboPalette.rouge,
      ],
    ),
  );
}

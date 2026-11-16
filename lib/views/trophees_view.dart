import 'package:flutter/material.dart';
import '../logic/accueil_logic.dart';
import '../theme.dart';
import '../widgets/microscope_icon.dart';

/// « Coin collection » : niveau, titre, diamants, combo, étoiles.
/// Page simple pour l'instant (le lot 3 l'enrichira).
class TropheesView extends StatelessWidget {
  final int diamants;
  final int combo;
  final int etoilesGagnees;
  final int etoilesTotal;

  const TropheesView({
    super.key,
    required this.diamants,
    required this.combo,
    required this.etoilesGagnees,
    required this.etoilesTotal,
  });

  @override
  Widget build(BuildContext context) {
    final niveau = niveauPour(diamants);
    final suite = prochainNiveauTexte(diamants);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Mes trophées",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: LaboPalette.ink,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: LaboPalette.nuit,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const MicroscopeIcon(size: 64),
              const SizedBox(height: 8),
              Text(
                "Niveau $niveau",
                style: const TextStyle(
                  color: LaboPalette.or,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                titreRangPour(niveau),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressionNiveau(diamants),
                  minHeight: 10,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(LaboPalette.or),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                suite ?? "🏆 Niveau maximum atteint",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _Tuile("💎", "$diamants", "diamants")),
            const SizedBox(width: 12),
            Expanded(child: _Tuile("🔥", "$combo", "combo")),
            const SizedBox(width: 12),
            Expanded(
              child: _Tuile("⭐", "$etoilesGagnees/$etoilesTotal", "étoiles"),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tuile extends StatelessWidget {
  final String emoji;
  final String valeur;
  final String nom;
  const _Tuile(this.emoji, this.valeur, this.nom);

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 4),
          Text(
            valeur,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: LaboPalette.ink,
            ),
          ),
          Text(nom, style: const TextStyle(color: LaboPalette.muted)),
        ],
      ),
    ),
  );
}

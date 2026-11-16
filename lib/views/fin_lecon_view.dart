import 'package:flutter/material.dart';
import '../logic/parcours_logic.dart';
import '../logic/trophees_logic.dart';
import '../theme.dart';
import '../widgets/badge_rond.dart';

/// Écran de récap : fin de leçon (3 étapes) ou fin d'une étape isolée.
class FinLeconView extends StatelessWidget {
  final bool leconComplete;

  /// Nom de l'étape (pour une étape isolée).
  final String nomEtape;

  /// Étoiles à montrer : x sur 3 (leçon complète) ou 0/1 (étape isolée).
  final int etoiles;
  final int etoilesMax;

  /// Diamants gagnés pendant ce passage.
  final int diamants;
  final String? succesLecon;
  final RecapParcours recap;
  final String message;
  final String libelleRetour;
  final VoidCallback onRetour;
  final VoidCallback onRejouer;

  const FinLeconView({
    super.key,
    required this.leconComplete,
    required this.nomEtape,
    required this.etoiles,
    required this.etoilesMax,
    required this.diamants,
    this.succesLecon,
    required this.recap,
    required this.message,
    required this.libelleRetour,
    required this.onRetour,
    required this.onRejouer,
  });

  @override
  Widget build(BuildContext context) {
    final aRetravailler = recap.aRetravailler;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              leconComplete ? "Leçon terminée" : "$nomEtape terminé",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: LaboPalette.ink,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < etoilesMax; i++)
                  _EtoileAnimee(allumee: i < etoiles, delaiMs: 250 * i),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "$etoiles étoile${etoiles > 1 ? 's' : ''} sur $etoilesMax",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: LaboPalette.muted),
            ),
            if (leconComplete &&
                etoiles >= 3 &&
                succesLecon != null &&
                succesLecon!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (_) {
                  final s = separerBadgeSucces(succesLecon, '');
                  final cle = choisirCleIconeBadge(s.nom, '', '');
                  final style = styleNiveauBadge(NiveauBadge.bronze);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: style.anneau.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: style.degrade.last.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        BadgeRond(
                          diametre: 44,
                          cleIcone: cle,
                          niveau: NiveauBadge.bronze,
                          emoji: s.emoji == '🏅'
                              ? emojiPourCleIcone(cle)
                              : s.emoji,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Badge débloqué : ${s.nom}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: LaboPalette.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, color: LaboPalette.ink),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: LaboShape.card,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.diamond, color: Colors.purple),
                  const SizedBox(width: 8),
                  Text(
                    "+$diamants diamant${diamants > 1 ? 's' : ''}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(
                  icone: Icons.bolt,
                  couleur: LaboPalette.good,
                  nombre: recap.premierCoup,
                  texte: "du 1er coup",
                ),
                const SizedBox(width: 8),
                _Stat(
                  icone: Icons.replay,
                  couleur: LaboPalette.warn,
                  nombre: recap.deuxiemeEssai,
                  texte: "au 2e essai",
                ),
                const SizedBox(width: 8),
                _Stat(
                  icone: Icons.flag,
                  couleur: Colors.blueGrey,
                  nombre: recap.rates,
                  texte: "à revoir",
                ),
              ],
            ),
            if (aRetravailler.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: LaboShape.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "À retravailler",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: LaboPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final t in aRetravailler.take(4))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          "• $t",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    if (aRetravailler.length > 4)
                      Text(
                        "et ${aRetravailler.length - 4} autre${aRetravailler.length - 4 > 1 ? 's' : ''}",
                        style: const TextStyle(
                          fontSize: 13,
                          color: LaboPalette.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetour,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                backgroundColor: LaboPalette.encre,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                libelleRetour,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: onRejouer,
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              child: Text(
                leconComplete ? "Rejouer" : "Rejouer l'étape",
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final int nombre;
  final String texte;
  const _Stat({
    required this.icone,
    required this.couleur,
    required this.nombre,
    required this.texte,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: LaboShape.card,
      ),
      child: Column(
        children: [
          Icon(icone, color: couleur, size: 22),
          Text(
            "$nombre",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: couleur,
            ),
          ),
          Text(
            texte,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: LaboPalette.ink),
          ),
        ],
      ),
    ),
  );
}

/// Étoile qui apparaît en rebondissant, l'une après l'autre.
class _EtoileAnimee extends StatelessWidget {
  final bool allumee;
  final int delaiMs;
  const _EtoileAnimee({required this.allumee, required this.delaiMs});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delaiMs),
      curve: Interval(
        delaiMs / (500 + delaiMs),
        1,
        curve: Curves.elasticOut,
      ),
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: Icon(
        allumee ? Icons.star : Icons.star_border,
        size: 64,
        color: allumee ? LaboPalette.touche : Colors.grey.shade400,
      ),
    );
  }
}

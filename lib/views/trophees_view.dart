import 'package:flutter/material.dart';
import '../logic/accueil_logic.dart';
import '../logic/trophees_logic.dart';
import '../theme.dart';
import '../widgets/badge_rond.dart';

/// « Mes trophées » : carte héros, badges de leçons, galerie des titres, stats.
class TropheesView extends StatelessWidget {
  final StatsTrophees stats;
  final List<BadgeLecon> badgesLecons;

  const TropheesView({
    super.key,
    required this.stats,
    this.badgesLecons = const [],
  });

  @override
  Widget build(BuildContext context) {
    final diamants = stats.diamants;
    final niveau = niveauPour(diamants);
    final titres = galerieTitres(niveau);
    final actuel = titres.firstWhere((t) => t.etat == EtatTitre.actuel);
    final nbDebloques = badgesLecons.where((b) => b.debloque).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Mes trophées",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: LaboPalette.ink,
          ),
        ),
        const SizedBox(height: 12),
        _CarteHeros(actuel: actuel, niveau: niveau, diamants: diamants),
        if (badgesLecons.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: _TitreSection("Mes badges de leçons")),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: LaboPalette.or.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: LaboPalette.or),
                ),
                child: Text(
                  "$nbDebloques/${badgesLecons.length}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: LaboPalette.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            itemCount: badgesLecons.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              mainAxisExtent: 140,
            ),
            itemBuilder: (_, i) => _PastilleBadgeSucces(badge: badgesLecons[i]),
          ),
        ],
        const SizedBox(height: 20),
        const _TitreSection("Mes titres"),
        const SizedBox(height: 8),
        for (final t in titres) _LigneTitre(titre: t),
        const SizedBox(height: 12),
        const _TitreSection("Mes chiffres"),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _CarteStat(
              icone: Icons.diamond,
              couleur: Colors.purple,
              valeur: "${stats.diamants}",
              nom: "diamants",
            ),
            _CarteStat(
              icone: Icons.local_fire_department,
              couleur: Colors.deepOrange,
              valeur: "${stats.combo}",
              nom: "combo en cours",
            ),
            _CarteStat(
              icone: Icons.star,
              couleur: Colors.amber.shade700,
              valeur: "${stats.etoilesGagnees}/${stats.etoilesTotal}",
              nom: "étoiles",
            ),
            _CarteStat(
              icone: Icons.workspace_premium,
              couleur: Colors.green,
              valeur: "${stats.leconsParfaites}/${stats.leconsTotal}",
              nom: "leçons à 3 étoiles",
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _TitreSection extends StatelessWidget {
  final String texte;
  const _TitreSection(this.texte);

  @override
  Widget build(BuildContext context) => Text(
    texte,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: LaboPalette.ink,
    ),
  );
}

class _CarteHeros extends StatelessWidget {
  final TitreRang actuel;
  final int niveau;
  final int diamants;
  const _CarteHeros({
    required this.actuel,
    required this.niveau,
    required this.diamants,
  });

  @override
  Widget build(BuildContext context) {
    final suite = prochainNiveauTexte(diamants);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [LaboPalette.nuit, Color(0xFF3949AB)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 104,
              height: 104,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(color: LaboPalette.or, width: 3),
              ),
              child: Text(actuel.emoji, style: const TextStyle(fontSize: 52)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            actuel.nom,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Niveau $niveau",
            style: const TextStyle(
              color: LaboPalette.or,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progressionNiveau(diamants)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            builder: (_, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 14,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(LaboPalette.or),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            suite ?? "Niveau maximum atteint !",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.diamond, color: LaboPalette.or, size: 22),
                const SizedBox(width: 8),
                Text(
                  "$diamants diamants",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneTitre extends StatelessWidget {
  final TitreRang titre;
  const _LigneTitre({required this.titre});

  @override
  Widget build(BuildContext context) {
    final verrouille = titre.etat == EtatTitre.verrouille;
    final actuel = titre.etat == EtatTitre.actuel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: verrouille
              ? Colors.grey.shade200
              : (actuel ? Colors.amber.shade50 : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: actuel ? LaboPalette.or : LaboPalette.line,
            width: actuel ? 3 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: verrouille
                    ? Colors.grey.shade300
                    : Colors.indigo.shade50,
              ),
              child: verrouille
                  ? const Icon(Icons.lock, color: Colors.grey, size: 26)
                  : Text(titre.emoji, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    verrouille ? "Titre mystère" : titre.nom,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: verrouille ? Colors.grey.shade600 : Colors.indigo,
                    ),
                  ),
                  Text(
                    verrouille
                        ? "Niveau ${titre.niveauMin}"
                        : (actuel
                              ? "Ton titre du moment"
                              : "Niveaux ${titre.niveauMin} à ${titre.niveauMax}"),
                    style: TextStyle(
                      fontSize: 13,
                      color: verrouille
                          ? Colors.grey.shade600
                          : LaboPalette.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (actuel)
              const Icon(Icons.stars, color: LaboPalette.or, size: 30)
            else if (!verrouille)
              const Icon(Icons.check_circle, color: LaboPalette.good, size: 26),
          ],
        ),
      ),
    );
  }
}

class _CarteStat extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String valeur;
  final String nom;
  const _CarteStat({
    required this.icone,
    required this.couleur,
    required this.valeur,
    required this.nom,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: couleur.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icone, color: couleur, size: 34),
        const SizedBox(height: 4),
        Text(
          valeur,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: couleur,
          ),
        ),
        Text(
          nom,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: LaboPalette.ink),
        ),
      ],
    ),
  );
}

class _PastilleBadgeSucces extends StatelessWidget {
  final BadgeLecon badge;
  const _PastilleBadgeSucces({required this.badge});

  void _ouvrirDetail(BuildContext context) {
    final style = styleNiveauBadge(badge.niveau);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BadgeRond(
              diametre: 84,
              cleIcone: badge.cleIcone,
              niveau: badge.niveau,
            ),
            const SizedBox(height: 12),
            Text(
              badge.nom,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: LaboPalette.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${badge.matiere} · ${badge.titreLecon}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: LaboPalette.muted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: style.pastille,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                badge.debloque
                    ? 'Niveau ${badge.niveau.rang} · ${badge.niveau.libelle}'
                    : 'Verrouillé (${badge.etoiles}/3 ⭐)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final n in [
                  NiveauBadge.bronze,
                  NiveauBadge.argent,
                  NiveauBadge.or,
                  NiveauBadge.diamant,
                ])
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: badge.niveau.rang >= n.rang ? 1.0 : 0.35,
                        child: BadgeRond(
                          diametre: 34,
                          cleIcone: badge.cleIcone,
                          niveau: n,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.libelle,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: badge.niveau == n
                              ? FontWeight.w900
                              : FontWeight.w600,
                          color: badge.niveau.rang >= n.rang
                              ? LaboPalette.ink
                              : LaboPalette.muted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              conseilProchainNiveau(badge),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: LaboPalette.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = styleNiveauBadge(badge.niveau);
    final etiquette = badge.debloque
        ? 'Niv. ${badge.niveau.rang} · ${badge.niveau.libelle}'
        : '🔒 ${badge.etoiles}/3 ⭐';
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _ouvrirDetail(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BadgeRond(
              diametre: 64,
              cleIcone: badge.cleIcone,
              niveau: badge.niveau,
            ),
            const SizedBox(height: 8),
            Text(
              badge.nom,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                height: 1.15,
                color: badge.debloque ? LaboPalette.ink : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badge.debloque ? style.pastille : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  etiquette,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: badge.debloque ? Colors.white : Colors.grey.shade800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

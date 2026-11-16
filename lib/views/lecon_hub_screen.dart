import 'package:flutter/material.dart';
import '../logic/accueil_logic.dart';
import '../logic/parcours_logic.dart';
import '../theme.dart';

/// Page d'une leçon : titre, maîtrise, les 3 étapes en grosses cartes et le
/// bouton « Faire toute la leçon ».
class LeconHubScreen extends StatefulWidget {
  final LeconRef lecon;
  final List<bool> Function() etoiles;
  final double Function() maitrise;
  final int Function() nbARevoir;

  /// Lance un parcours : [etapes] = étapes jouées, [complet] = toute la leçon.
  final Future<void> Function(List<int> etapes, {required bool complet})
  lancer;

  const LeconHubScreen({
    super.key,
    required this.lecon,
    required this.etoiles,
    required this.maitrise,
    required this.nbARevoir,
    required this.lancer,
  });

  @override
  State<LeconHubScreen> createState() => _LeconHubScreenState();
}

class _LeconHubScreenState extends State<LeconHubScreen> {
  static const _icones = [Icons.style, Icons.fitness_center, Icons.timer];
  static const _couleurs = [Colors.teal, Colors.blue, Colors.deepOrange];

  Future<void> _lancer(List<int> etapes, {required bool complet}) async {
    await widget.lancer(etapes, complet: complet);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lecon.lecon;
    final dispo = etapesDisponibles(l);
    final etoiles = widget.etoiles();
    final pct = (widget.maitrise() * 100).round();
    final aRevoir = widget.nbARevoir();
    return Scaffold(
      backgroundColor: LaboPalette.paper,
      appBar: AppBar(
        title: const Text(
          "Leçon",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l.titre,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: LaboPalette.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.lecon.matiere,
                style: const TextStyle(fontSize: 15, color: LaboPalette.muted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: widget.maitrise().clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: Colors.blue.shade100,
                        valueColor: const AlwaysStoppedAnimation(
                          LaboPalette.good,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Maîtrise $pct %",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: LaboPalette.ink,
                    ),
                  ),
                ],
              ),
              if (aRevoir > 0) ...[
                const SizedBox(height: 8),
                Text(
                  "$aRevoir à revoir",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              for (var i = 0; i < 3; i++)
                _CarteEtape(
                  icone: _icones[i],
                  couleur: _couleurs[i],
                  nom: kNomsEtapes[i],
                  disponible: dispo.contains(i),
                  faite: i < etoiles.length && etoiles[i],
                  onTap: () => _lancer([i], complet: false),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: dispo.isEmpty
                    ? null
                    : () => _lancer(dispo, complet: true),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  backgroundColor: LaboPalette.encre,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "Faire toute la leçon",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarteEtape extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String nom;
  final bool disponible;
  final bool faite;
  final VoidCallback onTap;

  const _CarteEtape({
    required this.icone,
    required this.couleur,
    required this.nom,
    required this.disponible,
    required this.faite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: LaboShape.card,
          onTap: disponible ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 84),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: disponible
                        ? couleur.withValues(alpha: 0.15)
                        : Colors.grey.shade200,
                    child: Icon(
                      icone,
                      color: disponible ? couleur : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          nom,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: LaboPalette.ink,
                          ),
                        ),
                        Text(
                          !disponible
                              ? "Pas de contenu"
                              : (faite ? "Faite" : "À faire"),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: faite ? LaboPalette.good : LaboPalette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (c, a) => ScaleTransition(
                      scale: CurvedAnimation(
                        parent: a,
                        curve: Curves.elasticOut,
                      ),
                      child: c,
                    ),
                    child: Row(
                      key: ValueKey(faite),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          faite ? Icons.star : Icons.star_border,
                          color: faite
                              ? LaboPalette.touche
                              : Colors.grey.shade400,
                          size: 30,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          faite ? "1/1" : "0/1",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../logic/accueil_logic.dart';
import '../theme.dart';

/// Liste de toutes les leçons, avec filtre par matière.
class LeconsView extends StatelessWidget {
  final List<LeconRef> toutes;
  final String? matiereChoisie; // null = « Toutes »
  final ValueChanged<String?> onMatiere;

  /// Étoiles, maîtrise (0 à 1) et nombre à revoir pour une leçon.
  final List<bool> Function(String titre) etoilesDe;
  final double Function(LeconRef) maitriseDe;
  final int Function(LeconRef) nbARevoirDe;

  final ValueChanged<LeconRef> onOuvrir;
  final VoidCallback onAjouter;
  final VoidCallback onParent;

  const LeconsView({
    super.key,
    required this.toutes,
    required this.matiereChoisie,
    required this.onMatiere,
    required this.etoilesDe,
    required this.maitriseDe,
    required this.nbARevoirDe,
    required this.onOuvrir,
    required this.onAjouter,
    required this.onParent,
  });

  @override
  Widget build(BuildContext context) {
    final matieres = <String>[];
    for (final r in toutes) {
      if (!matieres.contains(r.matiere)) matieres.add(r.matiere);
    }
    final visibles = filtrerParMatiere(toutes, matiereChoisie);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "Mes leçons",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: LaboPalette.ink,
                ),
              ),
            ),
            IconButton(
              tooltip: "Espace Parent",
              onPressed: onParent,
              icon: const Icon(Icons.settings, color: LaboPalette.muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ElevatedButton.icon(
          onPressed: onAjouter,
          icon: const Icon(Icons.add),
          label: const Text(
            "Ajouter une leçon",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: LaboPalette.encre,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text("Toutes"),
              selected: matiereChoisie == null,
              onSelected: (_) => onMatiere(null),
            ),
            for (final m in matieres)
              ChoiceChip(
                label: Text(m),
                selected: matiereChoisie == m,
                onSelected: (_) => onMatiere(m),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (visibles.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text("Aucune leçon ici.", textAlign: TextAlign.center),
          ),
        for (final r in visibles)
          _LigneLecon(
            ref: r,
            etoiles: etoilesDe(r.lecon.titre),
            maitrise: maitriseDe(r),
            nbARevoir: nbARevoirDe(r),
            onTap: () => onOuvrir(r),
          ),
      ],
    );
  }
}

class _LigneLecon extends StatelessWidget {
  final LeconRef ref;
  final List<bool> etoiles;
  final double maitrise;
  final int nbARevoir;
  final VoidCallback onTap;

  const _LigneLecon({
    required this.ref,
    required this.etoiles,
    required this.maitrise,
    required this.nbARevoir,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final n = nombreEtapesFaites(etoiles);
    final pct = (maitrise * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: LaboShape.card,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ref.lecon.titre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: LaboPalette.ink,
                          ),
                        ),
                      ),
                      Text(
                        "⭐ $n/3",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    ref.matiere,
                    style: const TextStyle(
                      fontSize: 12,
                      color: LaboPalette.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        "🧠 $pct %",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maitrise,
                            minHeight: 6,
                            backgroundColor: LaboPalette.line,
                            valueColor: AlwaysStoppedAnimation(
                              pct >= 80 ? LaboPalette.good : LaboPalette.encre,
                            ),
                          ),
                        ),
                      ),
                      if (nbARevoir > 0) ...[
                        const SizedBox(width: 10),
                        Text(
                          "$nbARevoir à revoir",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ],
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

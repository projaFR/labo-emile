import 'package:flutter/material.dart';
import '../logic/accueil_logic.dart';
import '../theme.dart';
import '../widgets/microscope_icon.dart';

/// Accueil « Aujourd'hui » : que fait Émile ce soir ?
class AujourdhuiView extends StatelessWidget {
  final int diamants;

  /// Leçon du soir (null s'il n'y a aucune leçon) et ses trois étoiles.
  final LeconRef? leconDuSoir;
  final List<bool> etoiles;

  /// Questions à revoir aujourd'hui (toutes leçons) et questions déjà suivies.
  final int nbARevoir;
  final int nbSuivies;

  final VoidCallback onContinuer;
  final VoidCallback onRevision;
  final VoidCallback onRevisionLibre;

  const AujourdhuiView({
    super.key,
    required this.diamants,
    required this.leconDuSoir,
    required this.etoiles,
    required this.nbARevoir,
    required this.nbSuivies,
    required this.onContinuer,
    required this.onRevision,
    required this.onRevisionLibre,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _bandeauNiveau(),
        const SizedBox(height: 16),
        if (leconDuSoir == null)
          const _CarteVide()
        else
          CarteLeconDuSoir(
            lecon: leconDuSoir!,
            etoiles: etoiles,
            onContinuer: onContinuer,
          ),
        const SizedBox(height: 16),
        _carteARevoir(),
      ],
    );
  }

  Widget _bandeauNiveau() {
    final niveau = niveauPour(diamants);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: LaboShape.card,
      ),
      child: Row(
        children: [
          const MicroscopeIcon(size: 28, color: LaboPalette.encre),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Nv.$niveau  ${titreRangPour(niveau)}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressionNiveau(diamants),
                    minHeight: 5,
                    backgroundColor: Colors.blue.shade100,
                    valueColor: AlwaysStoppedAnimation(Colors.blue.shade400),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            "💎 $diamants",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteARevoir() {
    final aRevoir = nbARevoir > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text("🔁", style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    aRevoir
                        ? "À revoir : $nbARevoir question${nbARevoir > 1 ? 's' : ''}"
                        : "Rien à revoir, bravo !",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: LaboPalette.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (aRevoir)
              OutlinedButton(
                onPressed: onRevision,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: LaboShape.card),
                ),
                child: const Text(
                  "Faire la révision du jour",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            else if (nbSuivies > 0)
              TextButton(
                onPressed: onRevisionLibre,
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text("Réviser quand même"),
              ),
          ],
        ),
      ),
    );
  }
}

class _CarteVide extends StatelessWidget {
  const _CarteVide();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        "Pas encore de leçon. Demande à un parent d'en ajouter une dans l'onglet Leçons.",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16),
      ),
    ),
  );
}

/// Grande carte « Leçon du soir » : une quête en trois étapes.
class CarteLeconDuSoir extends StatelessWidget {
  final LeconRef lecon;
  final List<bool> etoiles;
  final VoidCallback onContinuer;

  const CarteLeconDuSoir({
    super.key,
    required this.lecon,
    required this.etoiles,
    required this.onContinuer,
  });

  static const _etapes = ["Astuces", "Entraînement", "Défi chrono"];
  static const _icones = ["🃏", "🎯", "⏱️"];

  @override
  Widget build(BuildContext context) {
    final faites = nombreEtapesFaites(etoiles);
    final label = faites == 0
        ? "Commencer"
        : (faites == 3 ? "Rejouer la leçon" : "Continuer");
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFE0B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LaboPalette.warn, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "🌙 Leçon du soir",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            lecon.lecon.titre,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: LaboPalette.ink,
            ),
          ),
          Text(
            lecon.matiere,
            style: const TextStyle(fontSize: 14, color: LaboPalette.muted),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < 3; i++)
            _Etape(
              icone: _icones[i],
              nom: _etapes[i],
              faite: i < etoiles.length && etoiles[i],
            ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onContinuer,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              backgroundColor: LaboPalette.encre,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _Etape extends StatelessWidget {
  final String icone;
  final String nom;
  final bool faite;
  const _Etape({required this.icone, required this.nom, required this.faite});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (c, a) => ScaleTransition(
              scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
              child: c,
            ),
            child: Icon(
              faite ? Icons.check_circle : Icons.radio_button_unchecked,
              key: ValueKey(faite),
              color: faite ? LaboPalette.good : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(width: 10),
          Text(icone, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            nom,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: faite ? LaboPalette.good : LaboPalette.ink,
              decoration: faite ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../logic/trophees_logic.dart';
import '../theme.dart';

/// Palette visuelle d'un palier de badge (utilisable aussi pour les pastilles).
class StyleNiveauBadge {
  final List<Color> degrade;
  final Color anneau;
  final Color icone;
  final Color pastille;

  const StyleNiveauBadge({
    required this.degrade,
    required this.anneau,
    required this.icone,
    required this.pastille,
  });
}

StyleNiveauBadge styleNiveauBadge(NiveauBadge niveau) => switch (niveau) {
  NiveauBadge.verrouille => const StyleNiveauBadge(
    degrade: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
    anneau: Color(0xFF94A3B8),
    icone: Color(0xFF64748B),
    pastille: Color(0xFF64748B),
  ),
  NiveauBadge.bronze => const StyleNiveauBadge(
    degrade: [Color(0xFFE09153), Color(0xFF9A4E1C)],
    anneau: Color(0xFFF6D5B8),
    icone: Colors.white,
    pastille: Color(0xFF8D4011),
  ),
  NiveauBadge.argent => const StyleNiveauBadge(
    degrade: [Color(0xFFCFD8DC), Color(0xFF607D8B)],
    anneau: Color(0xFFECEFF1),
    icone: Colors.white,
    pastille: Color(0xFF455A64),
  ),
  NiveauBadge.or => const StyleNiveauBadge(
    degrade: [Color(0xFFFFE082), Color(0xFFF57F17)],
    anneau: Color(0xFFFFF8E1),
    icone: Colors.white,
    pastille: Color(0xFFE65100),
  ),
  NiveauBadge.diamant => const StyleNiveauBadge(
    degrade: [Color(0xFF26C6DA), Color(0xFF5E35B1)],
    anneau: LaboPalette.or,
    icone: Colors.white,
    pastille: Color(0xFF4527A0),
  ),
};

/// Petit médaillon circulaire contenant la silhouette monochrome de l'emoji du
/// badge et la pastille de son niveau.
class BadgeRond extends StatelessWidget {
  final double diametre;
  final String cleIcone;
  final NiveauBadge niveau;
  final String? emoji;

  const BadgeRond({
    super.key,
    this.diametre = 64,
    required this.cleIcone,
    required this.niveau,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    final style = styleNiveauBadge(niveau);
    final debloque = niveau != NiveauBadge.verrouille;
    final taillePastille = (diametre * 0.34).clamp(15.0, 24.0);
    final caractere = (emoji != null && emoji!.trim().isNotEmpty)
        ? emoji!.trim()
        : emojiPourCleIcone(cleIcone);
    return SizedBox(
      width: diametre,
      height: diametre,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: diametre,
            height: diametre,
            padding: EdgeInsets.all((diametre * 0.06).clamp(2.0, 4.0)),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: style.anneau,
              boxShadow: debloque
                  ? [
                      BoxShadow(
                        color: style.degrade.last.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: style.degrade,
                ),
              ),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(style.icone, BlendMode.srcIn),
                child: Text(
                  caractere,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: diametre * 0.44,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: taillePastille,
              height: taillePastille,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: style.pastille,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: _contenuPastille(taillePastille),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenuPastille(double taille) {
    return switch (niveau) {
      NiveauBadge.verrouille => Icon(
        Icons.lock,
        size: taille * 0.56,
        color: Colors.white,
      ),
      NiveauBadge.diamant => Icon(
        Icons.diamond,
        size: taille * 0.58,
        color: LaboPalette.or,
      ),
      NiveauBadge.bronze => _chiffre('I', taille),
      NiveauBadge.argent => _chiffre('II', taille),
      NiveauBadge.or => _chiffre('III', taille),
    };
  }

  Widget _chiffre(String texte, double taille) => Text(
    texte,
    style: TextStyle(
      color: Colors.white,
      fontSize: (taille * 0.48).clamp(8.0, 11.0),
      fontWeight: FontWeight.w900,
      height: 1.0,
    ),
  );
}

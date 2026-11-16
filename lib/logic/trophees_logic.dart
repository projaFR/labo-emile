import 'accueil_logic.dart';

/// Logique pure de la page Trophées (aucune dépendance à Flutter).

enum EtatTitre { debloque, actuel, verrouille }

/// Un des 10 titres RPG, avec son état pour un niveau donné.
class TitreRang {
  final int indice; // 0 à 9
  final String emoji;
  final String nom;
  final int niveauMin; // 1, 11, 21 … 91
  final int niveauMax; // 10, 20 … 100
  final EtatTitre etat;

  const TitreRang({
    required this.indice,
    required this.emoji,
    required this.nom,
    required this.niveauMin,
    required this.niveauMax,
    required this.etat,
  });
}

/// Sépare « 🥚 Œuf Mystérieux » en emoji + nom.
({String emoji, String nom}) separerTitre(String titre) {
  final i = titre.indexOf(' ');
  if (i < 0) return (emoji: '', nom: titre);
  return (emoji: titre.substring(0, i), nom: titre.substring(i + 1));
}

/// Les 10 titres, dans l'ordre, avec leur état pour [niveau].
List<TitreRang> galerieTitres(int niveau) {
  final courant = ((niveau - 1) ~/ 10).clamp(0, titresRang.length - 1);
  final liste = <TitreRang>[];
  for (var i = 0; i < titresRang.length; i++) {
    final s = separerTitre(titresRang[i]);
    liste.add(
      TitreRang(
        indice: i,
        emoji: s.emoji,
        nom: s.nom,
        niveauMin: i * 10 + 1,
        niveauMax: i * 10 + 10,
        etat: i < courant
            ? EtatTitre.debloque
            : (i == courant ? EtatTitre.actuel : EtatTitre.verrouille),
      ),
    );
  }
  return liste;
}

/// Chiffres de la page, calculés à partir des données déjà connues.
class StatsTrophees {
  final int diamants;
  final int combo;
  final int etoilesGagnees;
  final int etoilesTotal;
  final int leconsParfaites; // leçons avec les 3 étoiles
  final int leconsTotal;

  const StatsTrophees({
    required this.diamants,
    required this.combo,
    required this.etoilesGagnees,
    required this.etoilesTotal,
    required this.leconsParfaites,
    required this.leconsTotal,
  });
}

/// [etoilesParLecon] : une liste de 3 booléens par leçon.
StatsTrophees calculerStats({
  required int diamants,
  required int combo,
  required List<List<bool>> etoilesParLecon,
}) {
  var gagnees = 0;
  var parfaites = 0;
  for (final e in etoilesParLecon) {
    final n = nombreEtapesFaites(e);
    gagnees += n;
    if (n >= 3) parfaites++;
  }
  return StatsTrophees(
    diamants: diamants,
    combo: combo,
    etoilesGagnees: gagnees,
    etoilesTotal: etoilesParLecon.length * 3,
    leconsParfaites: parfaites,
    leconsTotal: etoilesParLecon.length,
  );
}

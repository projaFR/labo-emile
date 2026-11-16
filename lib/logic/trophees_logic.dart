import 'accueil_logic.dart';
import 'memoire.dart';

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

/// Paliers d'évolution d'un badge de leçon.
enum NiveauBadge {
  verrouille(0, 'Verrouillé'),
  bronze(1, 'Bronze'),
  argent(2, 'Argent'),
  or(3, 'Or'),
  diamant(4, 'Diamant');

  final int rang;
  final String libelle;
  const NiveauBadge(this.rang, this.libelle);
}

/// Calcule le niveau d'un badge de leçon :
/// - Verrouillé : moins de 3 étoiles sur la leçon
/// - Bronze (niv. 1) : les 3 étoiles obtenues
/// - Argent (niv. 2) : 3 étoiles + au moins 50 % des questions revues un autre jour (boîte >= 2)
/// - Or (niv. 3) : 3 étoiles + au moins 50 % des questions maîtrisées (boîte >= 3)
/// - Diamant (niv. 4) : 3 étoiles + au moins 85 % des questions maîtrisées (boîte >= 3)
NiveauBadge calculerNiveauBadge({
  required int etoiles,
  required double partRevues,
  required double maitrise,
}) {
  if (etoiles < 3) return NiveauBadge.verrouille;
  if (maitrise >= 0.85) return NiveauBadge.diamant;
  if (maitrise >= 0.50) return NiveauBadge.or;
  if (partRevues >= 0.50) return NiveauBadge.argent;
  return NiveauBadge.bronze;
}

const List<String> _clesIconesBadge = [
  'hibou',
  'compas',
  'calcul',
  'fusee',
  'eclair',
  'bouclier',
  'magie',
  'couronne',
  'plume',
  'livre',
  'science',
  'cerveau',
  'boussole',
  'globe',
  'sablier',
  'chateau',
  'langue',
  'flamme',
  'nature',
  'bateau',
  'ampoule',
  'puzzle',
  'cle',
  'trophee',
];

const List<(String cle, List<String> racines)> _tableIconesBadge = [
  ('hibou', ['hibou', 'oiseau', 'animal', 'renard', 'loup', 'chat']),
  ('compas', ['architect', 'compas', 'geometr', 'triangle', 'angle', 'mesur']),
  (
    'calcul',
    ['nombre', 'calcul', 'multipli', 'addition', 'table', 'fraction', 'divis'],
  ),
  ('fusee', ['fusee', 'pilote', 'espace', 'astre', 'planet']),
  ('eclair', ['eclair', 'tonnerre', 'foudre', 'vitesse', 'chrono']),
  ('bouclier', ['chevalier', 'bouclier', 'gardien', 'armure']),
  ('magie', ['mage', 'magie', 'sorcier', 'enchante', 'baguette']),
  ('couronne', ['roi', 'reine', 'couronne', 'empereur', 'prince']),
  (
    'plume',
    [
      'plume',
      'orthograph',
      'accord',
      'pluriel',
      'verbe',
      'grammair',
      'conjug',
      'mot',
      'lettre',
    ],
  ),
  ('livre', ['livre', 'lectur', 'conte', 'recit']),
  ('science', ['potion', 'scienc', 'chimi', 'atome', 'labo']),
  ('cerveau', ['cerveau', 'genie', 'savant', 'memoire', 'esprit']),
  ('boussole', ['explor', 'boussol', 'aventur', 'cap']),
  ('globe', ['monde', 'terre', 'geograph', 'carte', 'continent']),
  ('sablier', ['temps', 'siecle', 'passe', 'sablier', 'histoir']),
  ('chateau', ['chateau', 'forteresse', 'tour']),
  ('langue', ['anglais', 'langue', 'voix']),
  ('flamme', ['dragon', 'feu', 'flamme', 'volcan']),
  ('nature', ['foret', 'arbre', 'plante', 'natur', 'jardin']),
  ('bateau', ['pirate', 'mer', 'ocean', 'bateau', 'marin', 'navir']),
  ('ampoule', ['idee', 'astuce', 'lumier', 'inventeur']),
  ('puzzle', ['enigme', 'detectiv', 'puzzle', 'logiqu']),
  ('cle', ['secret', 'cle', 'tresor', 'coffre', 'code']),
];

String _sansAccents(String s) {
  const de = 'àâäéèêëîïôöùûüçœæ';
  const vers = 'aaaeeeeiioouuucoa';
  final buf = StringBuffer();
  for (final code in s.runes) {
    final c = String.fromCharCode(code);
    final i = de.indexOf(c);
    buf.write(i >= 0 ? vers[i] : c);
  }
  return buf.toString();
}

/// Choisit une clé d'icône vectorielle en fonction du nom de badge et de la leçon.
String choisirCleIconeBadge(
  String nomBadge,
  String titreLecon,
  String matiere,
) {
  final texte = _sansAccents('$nomBadge $titreLecon'.toLowerCase());
  final mots = [
    for (final m in RegExp(r'[a-z]+').allMatches(texte)) m.group(0)!,
  ];
  for (final (cle, racines) in _tableIconesBadge) {
    for (final mot in mots) {
      for (final r in racines) {
        if (r.length <= 4 ? mot == r || mot == '${r}s' || mot == '${r}x' : mot.startsWith(r)) {
          return cle;
        }
      }
    }
  }
  final cleTexte = '$nomBadge|$titreLecon|$matiere';
  var somme = 0;
  for (final c in cleTexte.codeUnits) {
    somme = (somme * 31 + c) & 0x7FFFFFFF;
  }
  return _clesIconesBadge[somme % _clesIconesBadge.length];
}

/// Un badge de succès attaché à une leçon (évolue avec les 3 étoiles puis la mémoire).
class BadgeLecon {
  final String titreLecon;
  final String matiere;
  final String emoji;
  final String nom;
  final String cleIcone;
  final NiveauBadge niveau;
  final int etoiles; // 0 à 3
  final double partRevues; // 0.0 à 1.0 (boîte >= 2)
  final double maitrise; // 0.0 à 1.0 (boîte >= 3)

  const BadgeLecon({
    required this.titreLecon,
    required this.matiere,
    required this.emoji,
    required this.nom,
    required this.cleIcone,
    required this.niveau,
    required this.etoiles,
    this.partRevues = 0,
    this.maitrise = 0,
  });

  bool get debloque => niveau != NiveauBadge.verrouille;
}

/// Extrait l'emoji et le nom d'un succès de leçon, avec repli propre si absent.
({String emoji, String nom}) separerBadgeSucces(
  String? succes,
  String titreLecon,
) {
  final propre = succes?.trim() ?? '';
  if (propre.isEmpty) {
    return (emoji: '🏅', nom: 'Champion · $titreLecon');
  }
  final s = separerTitre(propre);
  if (s.emoji.isEmpty || RegExp(r'[a-zA-Z]').hasMatch(s.emoji)) {
    return (emoji: '🏅', nom: propre);
  }
  return (emoji: s.emoji, nom: s.nom.trim());
}

/// Construit le badge d'une leçon à partir de ses 3 étoiles et de la mémoire.
BadgeLecon badgePourLecon(
  LeconRef r,
  List<bool> etoiles, {
  Memoire? memoire,
}) {
  final nb = nombreEtapesFaites(etoiles);
  final s = separerBadgeSucces(r.lecon.succes, r.lecon.titre);
  var partRevues = 0.0;
  var maitrise = 0.0;
  if (memoire != null) {
    final refs = questionsDeLecon(r.lecon);
    partRevues = memoire.partEnBoiteAuMoins(refs, 2);
    maitrise = memoire.maitrise(refs);
  }
  final niveau = calculerNiveauBadge(
    etoiles: nb,
    partRevues: partRevues,
    maitrise: maitrise,
  );
  return BadgeLecon(
    titreLecon: r.lecon.titre,
    matiere: r.matiere,
    emoji: s.emoji,
    nom: s.nom,
    cleIcone: choisirCleIconeBadge(s.nom, r.lecon.titre, r.matiere),
    niveau: niveau,
    etoiles: nb,
    partRevues: partRevues,
    maitrise: maitrise,
  );
}

/// Galerie des badges de toutes les leçons.
List<BadgeLecon> galerieBadgesLecons(
  List<LeconRef> lecons,
  List<bool> Function(String titre) etoilesDe, {
  Memoire? memoire,
}) => [
  for (final r in lecons)
    badgePourLecon(r, etoilesDe(r.lecon.titre), memoire: memoire),
];

/// Conseil court expliquant comment atteindre le palier suivant du badge.
String conseilProchainNiveau(BadgeLecon b) => switch (b.niveau) {
  NiveauBadge.verrouille =>
    'Gagne les 3 étoiles de la leçon (${b.etoiles}/3) pour débloquer le niveau Bronze.',
  NiveauBadge.bronze =>
    'Revois la moitié des questions un autre jour pour passer Argent (${(b.partRevues * 100).round()} % / 50 %).',
  NiveauBadge.argent =>
    'Maîtrise la moitié des questions en révision pour passer Or (${(b.maitrise * 100).round()} % / 50 %).',
  NiveauBadge.or =>
    'Maîtrise 85 % des questions en révision pour atteindre Diamant (${(b.maitrise * 100).round()} % / 85 %).',
  NiveauBadge.diamant =>
    'Niveau maximum atteint ! Cette leçon est bien ancrée.',
};



import '../models/lesson_model.dart';

/// Logique pure du parcours guidé et du récap de fin de leçon
/// (aucune dépendance à l'affichage : testable directement).

const List<String> kNomsEtapes = ["Astuces", "Entraînement", "Défi chrono"];

/// Résultat d'une étape (astuces, entraînement ou défi chrono).
class ResultatEtape {
  /// Questions réussies du premier coup.
  final int premierCoup;

  /// Questions réussies au 2e essai.
  final int deuxiemeEssai;

  /// Questions ratées (bonne réponse montrée, ou carte « à revoir »).
  final int rates;

  /// Diamants gagnés pendant l'étape.
  final int diamants;

  /// Étoile obtenue pendant cette étape.
  final bool etoile;

  /// Textes courts des questions ratées.
  final List<String> aRetravailler;

  /// Étape sautée (« Passer cette étape ») : rien à compter.
  final bool passee;

  const ResultatEtape({
    this.premierCoup = 0,
    this.deuxiemeEssai = 0,
    this.rates = 0,
    this.diamants = 0,
    this.etoile = false,
    this.aRetravailler = const [],
    this.passee = false,
  });

  const ResultatEtape.passee() : this(passee: true);

  ResultatEtape avecDiamants(int d) => ResultatEtape(
    premierCoup: premierCoup,
    deuxiemeEssai: deuxiemeEssai,
    rates: rates,
    diamants: d,
    etoile: etoile,
    aRetravailler: aRetravailler,
    passee: passee,
  );
}

/// Totaux d'un passage dans la leçon.
class RecapParcours {
  final int premierCoup;
  final int deuxiemeEssai;
  final int rates;
  final int diamants;
  final List<String> aRetravailler;
  const RecapParcours({
    required this.premierCoup,
    required this.deuxiemeEssai,
    required this.rates,
    required this.diamants,
    required this.aRetravailler,
  });
}

/// Cumule les résultats des étapes jouées (les étapes passées comptent zéro).
RecapParcours cumuler(Iterable<ResultatEtape> resultats) {
  var a = 0, b = 0, c = 0, d = 0;
  final textes = <String>[];
  for (final r in resultats) {
    if (r.passee) continue;
    a += r.premierCoup;
    b += r.deuxiemeEssai;
    c += r.rates;
    d += r.diamants;
    for (final t in r.aRetravailler) {
      if (!textes.contains(t)) textes.add(t);
    }
  }
  return RecapParcours(
    premierCoup: a,
    deuxiemeEssai: b,
    rates: c,
    diamants: d,
    aRetravailler: textes,
  );
}

/// Étapes qui ont du contenu dans la leçon (indices 0, 1, 2).
List<int> etapesDisponibles(LessonModel l) => [
  if (l.astuces.isNotEmpty) 0,
  if (l.exercices.isNotEmpty) 1,
  if (l.quiz.isNotEmpty) 2,
];

/// Position (dans [etapes]) de la première étape non faite ; 0 si tout est
/// fait (on rejoue depuis le début).
int departParcours(List<int> etapes, List<bool> etoiles) {
  for (var p = 0; p < etapes.length; p++) {
    final i = etapes[p];
    if (i >= etoiles.length || !etoiles[i]) return p;
  }
  return 0;
}

/// Position de l'étape suivante, ou null après la dernière.
int? etapeSuivante(int position, int total) =>
    position + 1 < total ? position + 1 : null;

/// Texte « Étape 2 sur 3 · Entraînement ».
String libelleEtape(int position, int total, int indiceEtape) =>
    "Étape ${position + 1} sur $total · ${kNomsEtapes[indiceEtape]}";

/// Progression (0 à 1) de la barre : étapes terminées / total.
double progressionParcours(int position, int total) =>
    total == 0 ? 0 : (position / total).clamp(0.0, 1.0);

/// Étoiles (sur 3) à montrer dans le récap : celles déjà possédées avant le
/// passage plus celles obtenues pendant le passage.
int etoilesRecap(List<bool> avant, Map<int, ResultatEtape> resultats) {
  var n = 0;
  for (var i = 0; i < 3; i++) {
    final avais = i < avant.length && avant[i];
    final gagnee = resultats[i]?.etoile ?? false;
    if (avais || gagnee) n++;
  }
  return n;
}

/// Texte court d'une question : trous « [?] » remplacés, longueur limitée.
String texteCourt(String question, {int max = 60}) {
  final t = question
      .replaceAll('[?]', '…')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (t.length <= max) return t;
  return '${t.substring(0, max - 1).trimRight()}…';
}

/// Message d'encouragement varié, selon les étoiles (0 à 3). [graine] choisit
/// la variante (jamais plus d'un point d'exclamation).
String messageEncouragement(int etoiles, {int graine = 0}) {
  const parfait = [
    "Quel beau travail, tu sais tout cela.",
    "Trois étoiles ! Tu peux être fier de toi.",
    "Tu maîtrises cette leçon.",
  ];
  const bien = [
    "Très bien joué, il ne reste presque rien à retravailler.",
    "Beau parcours, continue comme ça.",
    "Tu progresses vite.",
  ];
  const debut = [
    "Un bon début, la prochaine fois sera encore meilleure.",
    "Tu as fait le plus dur, bravo d'avoir essayé.",
    "Chaque essai te fait grandir.",
  ];
  final liste = etoiles >= 3 ? parfait : (etoiles >= 1 ? bien : debut);
  return liste[graine.abs() % liste.length];
}

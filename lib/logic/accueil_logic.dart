import 'memoire.dart';
import '../models/lesson_model.dart';

/// Logique pure de l'accueil, des leçons et des trophées (aucune dépendance
/// à Flutter ni au stockage : testable directement).

/// Une leçon avec sa matière.
class LeconRef {
  final String matiere;
  final LessonModel lecon;
  const LeconRef(this.matiere, this.lecon);
}

/// Aplatit la base (matière -> leçons) en une liste, dans l'ordre de la base.
List<LeconRef> aplatir(Map<String, List<LessonModel>> base) => [
  for (final e in base.entries)
    for (final l in e.value) LeconRef(e.key, l),
];

/// Choisit la « Leçon du soir » :
/// 1. la leçon importée en dernier, si on la connaît et qu'elle existe encore ;
/// 2. sinon la dernière leçon importée de la liste (hors leçons de base) ;
/// 3. sinon la première leçon de base ;
/// null s'il n'y a aucune leçon.
LeconRef? choisirLeconDuSoir(
  List<LeconRef> toutes,
  Set<String> titresBase, {
  String? derniereImportee,
}) {
  if (toutes.isEmpty) return null;
  if (derniereImportee != null) {
    for (final r in toutes) {
      if (r.lecon.titre == derniereImportee && !titresBase.contains(derniereImportee)) {
        return r;
      }
    }
  }
  final importees = toutes.where((r) => !titresBase.contains(r.lecon.titre));
  if (importees.isNotEmpty) return importees.last;
  return toutes.first;
}

/// Indice (0 astuces, 1 entraînement, 2 défi chrono) de la première étape non
/// faite, ou -1 si les trois sont faites.
int premiereEtapeNonFaite(List<bool> etoiles) {
  for (var i = 0; i < 3; i++) {
    if (i >= etoiles.length || !etoiles[i]) return i;
  }
  return -1;
}

/// Nombre d'étapes faites (0 à 3).
int nombreEtapesFaites(List<bool> etoiles) =>
    etoiles.take(3).where((b) => b).length;

/// Filtre par matière ; [matiere] null = « Toutes ».
List<LeconRef> filtrerParMatiere(List<LeconRef> toutes, String? matiere) =>
    matiere == null
    ? List.of(toutes)
    : toutes.where((r) => r.matiere == matiere).toList();

/// Nombre de questions de la leçon à revoir aujourd'hui.
int nbARevoirLecon(Memoire memoire, LessonModel lecon) =>
    memoire.nombreDues(questionsDeLecon(lecon));

// ── Niveaux RPG (100 niveaux, un titre tous les 10) ─────────────────────────

const List<String> titresRang = [
  "🥚 Œuf Mystérieux",
  "🐣 Poussin Curieux",
  "🗡️ Recrue Courageuse",
  "🛡️ Chevalier Junior",
  "🏹 Archer Savant",
  "🔮 Mage des Formules",
  "🐉 Dompteur de Dragons",
  "⚡ Maître du Tonnerre",
  "💫 Élu des Étoiles",
  "👑 Dieu du Savoir",
];

int seuilNiveau(int niveau) {
  if (niveau <= 1) return 0;
  var total = 0;
  for (var i = 1; i < niveau; i++) {
    total += i * 8;
  }
  return total;
}

int niveauPour(int diamants) {
  var niveau = 1;
  for (var i = 2; i <= 100; i++) {
    if (diamants >= seuilNiveau(i)) {
      niveau = i;
    } else {
      break;
    }
  }
  return niveau;
}

String titreRangPour(int niveau) =>
    titresRang[((niveau - 1) ~/ 10).clamp(0, titresRang.length - 1)];

String badgePour(int diamants) {
  final n = niveauPour(diamants);
  return "Nv.$n - ${titreRangPour(n)}";
}

/// Progression (0 à 1) vers le niveau suivant.
double progressionNiveau(int diamants) {
  final n = niveauPour(diamants);
  if (n >= 100) return 1.0;
  final a = seuilNiveau(n);
  final b = seuilNiveau(n + 1);
  return ((diamants - a) / (b - a)).clamp(0.0, 1.0);
}

/// Texte « Prochain : … à N 💎 » ou null au niveau maximum.
String? prochainNiveauTexte(int diamants) {
  final n = niveauPour(diamants);
  if (n >= 100) return null;
  final rang = titresRang[(n ~/ 10).clamp(0, titresRang.length - 1)];
  return "Prochain : Nv.${n + 1} - $rang à ${seuilNiveau(n + 1)} 💎";
}

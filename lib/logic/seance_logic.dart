import 'dart:math';
import '../models/lesson_model.dart';

/// Logique pure (sans affichage) des séances, essais, combo et chrono.
/// Séparée des écrans pour pouvoir être testée.

/// Nombre d'exercices d'une séance.
const int kTailleSeance = 10;

/// Nombre d'essais permis par exercice.
const int kEssaisMax = 2;

/// Résultat d'une validation.
enum ResultatEssai {
  /// Bonne réponse (au 1er ou au 2e essai).
  juste,

  /// Faux au 1er essai : on affiche l'indice et on laisse réessayer.
  reessayer,

  /// Faux au 2e essai : on montre la bonne réponse.
  montrerReponse,
}

ResultatEssai resoudreEssai({required bool estJuste, required int essai}) {
  if (estJuste) return ResultatEssai.juste;
  return essai < kEssaisMax
      ? ResultatEssai.reessayer
      : ResultatEssai.montrerReponse;
}

/// L'étoile est obtenue si aucun exercice n'a fini « montré » :
/// tout est juste, au besoin au 2e essai.
bool etoileExercices(int exercicesRates) => exercicesRates == 0;

/// Une erreur fait redescendre le combo d'un cran (jamais sous 0).
int comboApresErreur(int combo) => combo > 0 ? combo - 1 : 0;

/// Texte de la bonne réponse, y compris pour les nombres.
String texteBonneReponse(ExerciseModel ex) {
  if (ex.reponsesMultiples.isNotEmpty) {
    return ex.reponsesMultiples.map((r) => r.trim()).join(' ; ');
  }
  return ex.reponseAttendue.trim();
}

/// Séance tirée : indices dans la leçon + nouvel ensemble des « déjà vus ».
class SeanceTiree {
  final List<int> indices;
  final Set<int> vusApres;
  const SeanceTiree(this.indices, this.vusApres);
}

/// Tire une séance de [taille] exercices parmi [total].
/// - On pioche d'abord parmi ceux pas encore vus (pas de répétition tant
///   qu'il en reste).
/// - Quand il n'en reste plus assez, on prend ceux qui restent puis on
///   complète avec des déjà vus : un nouveau tour commence.
/// - Ordre de la séance : celui de la leçon (aucune difficulté dans le
///   format JSON, donc pas de palier déterminable).
SeanceTiree tirerSeance(
  int total,
  Set<int> vus, {
  int taille = kTailleSeance,
  Random? rng,
}) {
  final random = rng ?? Random();
  if (total <= 0) return const SeanceTiree([], {});
  final tous = List<int>.generate(total, (i) => i);
  final vusValides = vus.where((i) => i >= 0 && i < total).toSet();
  var nonVus = tous.where((i) => !vusValides.contains(i)).toList();

  if (nonVus.isEmpty) {
    // Tout a été vu : nouveau tour.
    nonVus = List<int>.from(tous);
    vusValides.clear();
  }

  if (total <= taille) {
    return SeanceTiree(tous, {...tous});
  }

  if (nonVus.length >= taille) {
    nonVus.shuffle(random);
    final choix = nonVus.take(taille).toList()..sort();
    return SeanceTiree(choix, {...vusValides, ...choix});
  }

  // Fin de tour : les derniers non vus + complément pris dans les déjà vus.
  final complement = tous.where((i) => !nonVus.contains(i)).toList()
    ..shuffle(random);
  final ajout = complement.take(taille - nonVus.length).toList();
  final choix = [...nonVus, ...ajout]..sort();
  // Nouveau tour : seuls les compléments comptent comme vus.
  return SeanceTiree(choix, {...ajout});
}

/// Manche de quiz : gère diamants, bonnes réponses et temps écoulé.
class MancheQuiz {
  final int secondes; // 0 = sans chrono
  int bonnes = 0;
  int manquees = 0; // temps écoulé : « pas encore », pas une faute
  int erreurs = 0;

  MancheQuiz(this.secondes);

  bool get chrono => secondes > 0;

  /// Diamants pour une bonne réponse. Bonus de rapidité si on répond
  /// pendant le premier tiers du temps (>10 s restantes sur 15 s, comme avant).
  int repondreJuste(int secondesRestantes) {
    bonnes++;
    if (chrono && secondesRestantes * 3 > secondes * 2) return 2;
    return 1;
  }

  /// Faux : compte comme erreur (combo).
  void repondreFaux() => erreurs++;

  /// Temps écoulé : ni faute ni diamant ; la bonne réponse est montrée.
  void tempsEcoule() => manquees++;

  /// Étoile : tout juste, sans temps écoulé.
  bool etoile(int nbQuestions) =>
      bonnes == nbQuestions && erreurs == 0 && manquees == 0;
}

import 'dart:convert';
import '../models/lesson_model.dart';

/// Mémoire par question (méthode des boîtes, comme Réviser).
/// Dart pur : aucune dépendance à Flutter ni au stockage. L'horloge est
/// injectable pour les tests, et toutes les dates sont des jours LOCAUX
/// au format AAAA-MM-JJ.
///
/// Écarts avec Réviser (leitner.dart) :
/// - intervalles 1 – 2 – 4 – 8 – 16 jours (au lieu de 1 – 3 – 7 – 14 – 30) ;
/// - une question déjà programmée (pas encore due) qui est réussie du premier
///   coup ne change pas de boîte : rejouer une leçon le même jour ne fait pas
///   grimper les boîtes (Réviser ne propose que des notions dues, le Labo
///   laisse rejouer n'importe quand).
///
/// IDENTITÉ D'UNE QUESTION : empreinte du titre de la leçon + type + texte de
/// la question. Une leçon réimportée avec les mêmes questions retrouve donc sa
/// mémoire ; une question dont le texte (ou la leçon dont le titre) change
/// repart de zéro. Le format JSON des leçons n'est pas modifié.

/// Version du format de stockage.
const int kVersionMemoire = 1;

/// Nombre de jours avant le retour, selon la boîte (0 = jamais vue).
const List<int> kIntervallesJours = [0, 1, 2, 4, 8, 16];

const int kBoiteMax = 5;

/// Boîte à partir de laquelle une question compte comme « maîtrisée ».
const int kBoiteMaitrisee = 3;

/// Taille maximale de la Révision du jour.
const int kTailleRevision = 12;

/// Diamants fixes pour la Révision du jour terminée (une fois par jour).
const int kDiamantsRevision = 3;

typedef Horloge = DateTime Function();

enum TypeQuestion {
  astuce('a'),
  exercice('e'),
  quiz('q');

  final String code;
  const TypeQuestion(this.code);
}

/// Comment une question a été répondue.
enum Resultat {
  /// Bonne réponse du premier coup (ou carte « Maîtrisé »).
  premierCoup,

  /// Juste au 2e essai, ou temps écoulé : « pas encore sûr ».
  deuxiemeEssai,

  /// Faux deux fois (ou carte « À revoir », ou quiz faux).
  rate,
}

// ── Dates (jours locaux) ─────────────────────────────────────────────────────

String jourLocal(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Ajoute des jours de calendrier (insensible au changement d'heure).
String ajouterJours(DateTime d, int jours) =>
    jourLocal(DateTime(d.year, d.month, d.day + jours));

// ── Empreinte ────────────────────────────────────────────────────────────────

/// FNV-1a 32 bits (calcul sûr aussi en JavaScript : pas de produit > 2^53).
int _fnv1a32(List<int> octets, int depart) {
  var h = depart;
  for (final o in octets) {
    h = (h ^ o) % 4294967296;
    // h * 16777619 = h * (2^24 + 0x193), décomposé pour rester < 2^53.
    h = ((h % 256) * 16777216 + h * 0x193) % 4294967296;
  }
  return h;
}

/// Empreinte stable (16 caractères hexa) : deux FNV-1a 32 bits de départs
/// différents, pour rendre une collision très improbable.
String empreinte(String texte) {
  final octets = utf8.encode(texte);
  final a = _fnv1a32(octets, 0x811C9DC5);
  final b = _fnv1a32(octets, 0x01234567);
  return a.toRadixString(16).padLeft(8, '0') +
      b.toRadixString(16).padLeft(8, '0');
}

/// Clé stable d'une question.
String cleQuestion(String titreLecon, TypeQuestion type, String texte) =>
    empreinte('$titreLecon\u0001${type.code}\u0001$texte');

/// Référence à une question d'une leçon.
class RefQuestion {
  final LessonModel lecon;
  final TypeQuestion type;
  final int index;
  final String cle;
  const RefQuestion(this.lecon, this.type, this.index, this.cle);
}

/// Nombre de vrais calculs d'empreintes faits par [questionsDeLecon]
/// (sert aux tests : le résultat est gardé en cache par leçon).
int compteurCalculsQuestions = 0;

final Expando<List<RefQuestion>> _cacheQuestions = Expando('questionsDeLecon');

/// Toutes les questions d'une leçon (cartes, exercices, quiz).
/// Une leçon est immuable : le résultat est calculé une seule fois (les
/// empreintes ne sont plus recalculées à chaque reconstruction de l'accueil).
List<RefQuestion> questionsDeLecon(LessonModel l) {
  final enCache = _cacheQuestions[l];
  if (enCache != null) return enCache;
  compteurCalculsQuestions++;
  return _cacheQuestions[l] = List.unmodifiable(_calculerQuestions(l));
}

List<RefQuestion> _calculerQuestions(LessonModel l) => [
  for (var i = 0; i < l.astuces.length; i++)
    RefQuestion(
      l,
      TypeQuestion.astuce,
      i,
      cleQuestion(l.titre, TypeQuestion.astuce, l.astuces[i].question),
    ),
  for (var i = 0; i < l.exercices.length; i++)
    RefQuestion(
      l,
      TypeQuestion.exercice,
      i,
      cleQuestion(l.titre, TypeQuestion.exercice, l.exercices[i].question),
    ),
  for (var i = 0; i < l.quiz.length; i++)
    RefQuestion(
      l,
      TypeQuestion.quiz,
      i,
      cleQuestion(l.titre, TypeQuestion.quiz, l.quiz[i].question),
    ),
];

// ── État d'une question ──────────────────────────────────────────────────────

class EtatQuestion {
  /// Boîte de 1 à 5.
  final int boite;

  /// Jour de retour (AAAA-MM-JJ).
  final String retour;
  final int reps;
  final int ratees;

  const EtatQuestion({
    required this.boite,
    required this.retour,
    this.reps = 0,
    this.ratees = 0,
  });

  bool estDue(String aujourdhui) => retour.compareTo(aujourdhui) <= 0;

  Map<String, dynamic> toJson() => {
    'b': boite,
    'd': retour,
    'r': reps,
    'l': ratees,
  };

  /// Lève une exception si les données sont invalides.
  factory EtatQuestion.fromJson(Object? j) {
    final m = j as Map<String, dynamic>;
    final b = m['b'] as int;
    final d = m['d'] as String;
    if (b < 1 || b > kBoiteMax) throw const FormatException('boîte');
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d)) {
      throw const FormatException('date');
    }
    return EtatQuestion(
      boite: b,
      retour: d,
      reps: (m['r'] as int?) ?? 0,
      ratees: (m['l'] as int?) ?? 0,
    );
  }
}

/// Résultat d'une lecture du stockage.
class LectureMemoire {
  final Memoire memoire;

  /// Vrai si le texte lu était illisible : l'appelant doit alors garder
  /// l'ancien texte brut dans une clé de secours.
  final bool corrompue;
  const LectureMemoire(this.memoire, this.corrompue);
}

class Memoire {
  final Horloge horloge;
  final Map<String, EtatQuestion> _etats;

  Memoire({Horloge? horloge, Map<String, EtatQuestion>? etats})
    : horloge = horloge ?? DateTime.now,
      _etats = {...?etats};

  String get aujourdhui => jourLocal(horloge());

  int get nombreSuivies => _etats.length;

  Map<String, EtatQuestion> get etats => Map.unmodifiable(_etats);

  EtatQuestion? etat(String cle) => _etats[cle];

  /// Enregistre une réponse. Voir les règles en tête de fichier.
  void enregistrer(String cle, Resultat r) {
    final now = horloge();
    final auj = jourLocal(now);
    final demain = ajouterJours(now, 1);
    final ancien = _etats[cle];
    final programmee = ancien != null && !ancien.estDue(auj);

    EtatQuestion nouveau;
    switch (r) {
      case Resultat.premierCoup:
        if (programmee) {
          // Déjà programmée plus tard : on ne fait pas grimper la boîte.
          nouveau = EtatQuestion(
            boite: ancien.boite,
            retour: ancien.retour,
            reps: ancien.reps + 1,
            ratees: ancien.ratees,
          );
        } else {
          final b = ancien == null
              ? 1
              : (ancien.boite >= kBoiteMax ? kBoiteMax : ancien.boite + 1);
          nouveau = EtatQuestion(
            boite: b,
            retour: ajouterJours(now, kIntervallesJours[b]),
            reps: (ancien?.reps ?? 0) + 1,
            ratees: ancien?.ratees ?? 0,
          );
        }
      case Resultat.deuxiemeEssai:
        final b = ancien?.boite ?? 1;
        final retour = programmee && ancien.retour.compareTo(demain) < 0
            ? ancien.retour
            : demain;
        nouveau = EtatQuestion(
          boite: b,
          retour: retour,
          reps: (ancien?.reps ?? 0) + 1,
          ratees: ancien?.ratees ?? 0,
        );
      case Resultat.rate:
        nouveau = EtatQuestion(
          boite: 1,
          retour: demain,
          reps: (ancien?.reps ?? 0) + 1,
          ratees: (ancien?.ratees ?? 0) + 1,
        );
    }
    _etats[cle] = nouveau;
  }

  bool estDue(String cle) {
    final e = _etats[cle];
    return e != null && e.estDue(aujourdhui);
  }

  /// Questions dues parmi [refs], les plus en retard d'abord (date de retour
  /// la plus ancienne, puis boîte la plus basse, puis clé pour un ordre
  /// stable). Une même question n'apparaît qu'une fois.
  List<RefQuestion> dues(Iterable<RefQuestion> refs, {int max = kTailleRevision}) {
    final auj = aujourdhui;
    final vues = <String>{};
    final liste = <RefQuestion>[];
    for (final r in refs) {
      final e = _etats[r.cle];
      if (e == null || !e.estDue(auj)) continue;
      if (vues.add(r.cle)) liste.add(r);
    }
    liste.sort((a, b) {
      final ea = _etats[a.cle]!;
      final eb = _etats[b.cle]!;
      final c = ea.retour.compareTo(eb.retour);
      if (c != 0) return c;
      final cb = ea.boite.compareTo(eb.boite);
      if (cb != 0) return cb;
      return a.cle.compareTo(b.cle);
    });
    return liste.take(max).toList();
  }

  /// Pour « Réviser quand même » : jusqu'à [max] questions déjà suivies (même
  /// pas dues), les plus faibles d'abord (boîte la plus basse), puis les plus
  /// anciennement vues (date de retour la plus ancienne). Ne change rien au
  /// calendrier : c'est seulement une sélection.
  List<RefQuestion> plusFaibles(
    Iterable<RefQuestion> refs, {
    int max = kTailleRevision,
  }) {
    final vues = <String>{};
    final liste = <RefQuestion>[];
    for (final r in refs) {
      if (_etats[r.cle] == null) continue;
      if (vues.add(r.cle)) liste.add(r);
    }
    liste.sort((a, b) {
      final ea = _etats[a.cle]!;
      final eb = _etats[b.cle]!;
      final cb = ea.boite.compareTo(eb.boite);
      if (cb != 0) return cb;
      final c = ea.retour.compareTo(eb.retour);
      if (c != 0) return c;
      return a.cle.compareTo(b.cle);
    });
    return liste.take(max).toList();
  }

  /// Nombre total de questions dues parmi [refs] (sans limite de 12).
  int nombreDues(Iterable<RefQuestion> refs) =>
      dues(refs, max: 1 << 30).length;

  /// Part (0 à 1) des questions de [refs] qui sont dans une boîte >= [boiteMin].
  double partEnBoiteAuMoins(Iterable<RefQuestion> refs, int boiteMin) {
    final cles = {for (final r in refs) r.cle};
    if (cles.isEmpty) return 0;
    final ok = cles.where((c) => (_etats[c]?.boite ?? 0) >= boiteMin);
    return ok.length / cles.length;
  }

  /// Part (0 à 1) des questions de [refs] en boîte >= [kBoiteMaitrisee].
  double maitrise(Iterable<RefQuestion> refs) =>
      partEnBoiteAuMoins(refs, kBoiteMaitrisee);

  /// Nombre de questions de [refs] suivies (déjà répondues au moins une fois).
  int nombreSuiviesParmi(Iterable<RefQuestion> refs) =>
      {for (final r in refs) r.cle}.where(_etats.containsKey).length;

  /// Efface toute la mémoire.
  void reinitialiser() => _etats.clear();

  // ── JSON versionné ─────────────────────────────────────────────────────────

  String toJsonString() => jsonEncode({
    'version': kVersionMemoire,
    'questions': {for (final e in _etats.entries) e.key: e.value.toJson()},
  });

  /// Lit le texte stocké. Texte absent ou vide : mémoire vide, pas corrompue.
  /// Toute anomalie (JSON invalide, mauvaise version, entrée invalide) :
  /// mémoire vide et [LectureMemoire.corrompue] vrai, sans rien jeter.
  static LectureMemoire lire(String? brut, {Horloge? horloge}) {
    if (brut == null || brut.isEmpty) {
      return LectureMemoire(Memoire(horloge: horloge), false);
    }
    try {
      final j = jsonDecode(brut) as Map<String, dynamic>;
      if (j['version'] != kVersionMemoire) {
        throw const FormatException('version');
      }
      final q = j['questions'] as Map<String, dynamic>;
      final etats = {
        for (final e in q.entries) e.key: EtatQuestion.fromJson(e.value),
      };
      return LectureMemoire(Memoire(horloge: horloge, etats: etats), false);
    } catch (_) {
      return LectureMemoire(Memoire(horloge: horloge), true);
    }
  }
}

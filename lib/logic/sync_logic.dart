import 'dart:convert';

import '../models/lesson_model.dart';
import 'memoire.dart';

/// Logique pure (sans Flutter ni réseau) de synchronisation des leçons et de
/// la progression d'Émile.

String _sansAccentsSync(String s) {
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

/// Identifiant Firestore stable, lisible et sûr pour une leçon.
String identifiantLeconSync(String matiere, String titre) {
  final slug = _sansAccentsSync('$matiere-$titre'.toLowerCase())
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  var court = slug.length > 48 ? slug.substring(0, 48) : slug;
  court = court.replaceAll(RegExp(r'-+$'), '');
  if (court.isEmpty) court = 'lecon';
  final hash = empreinte(
    '${matiere.trim().toLowerCase()}|${titre.trim().toLowerCase()}',
  ).substring(0, 8);
  return '${court}_$hash';
}

/// Représentation d'une leçon dans la collection Firestore `labo_lecons`.
class LeconSyncDistante {
  final String id;
  final String matiere;
  final LessonModel? lecon;
  final String modifieLe;
  final bool supprimee;

  const LeconSyncDistante({
    required this.id,
    required this.matiere,
    required this.lecon,
    required this.modifieLe,
    this.supprimee = false,
  });

  Map<String, Object?> toFirestoreFields() => {
    'matiere': matiere,
    'titre': lecon?.titre ?? '',
    'json': lecon == null ? '' : jsonEncode(lecon!.toJson()),
    'modifieLe': modifieLe,
    'supprimee': supprimee,
  };

  static LeconSyncDistante? tryFromFirestoreFields(
    String id,
    Map<String, Object?> fields,
  ) {
    final rawMatiere = fields['matiere'];
    final matiere = (rawMatiere is String && rawMatiere.trim().isNotEmpty)
        ? rawMatiere.trim()
        : 'Mathématiques';
    final modifieLe = (fields['modifieLe'] is String)
        ? fields['modifieLe'] as String
        : '';
    final supprimee = fields['supprimee'] == true;
    if (supprimee) {
      return LeconSyncDistante(
        id: id,
        matiere: matiere,
        lecon: null,
        modifieLe: modifieLe,
        supprimee: true,
      );
    }
    final rawJson = fields['json'];
    if (rawJson is! String || rawJson.trim().isEmpty) return null;
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      final lecon = LessonModel.fromJson(map);
      return LeconSyncDistante(
        id: id,
        matiere: matiere,
        lecon: lecon,
        modifieLe: modifieLe,
        supprimee: false,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Résultat de la fusion entre les leçons locales (hors base) et distantes.
class ResultatFusionLecons {
  final Map<String, List<LessonModel>> localesFusionnees;
  final List<LeconSyncDistante> aEnvoyer;
  final Map<String, String> suppressionsRestantes;
  final bool modifieLocalement;

  const ResultatFusionLecons({
    required this.localesFusionnees,
    required this.aEnvoyer,
    required this.suppressionsRestantes,
    required this.modifieLocalement,
  });
}

ResultatFusionLecons fusionnerLecons({
  required Map<String, List<LessonModel>> localesCustom,
  required Map<String, LeconSyncDistante> distantes,
  required Map<String, String> suppressionsLocales,
  required Set<String> titresBase,
  Map<String, String> modifsLocales = const {},
  String? maintenantIso,
}) {
  final now = maintenantIso ?? DateTime.now().toUtc().toIso8601String();
  final localesParId = <String, ({String matiere, LessonModel lecon})>{};
  for (final e in localesCustom.entries) {
    for (final l in e.value) {
      if (titresBase.contains(l.titre)) continue;
      final id = identifiantLeconSync(e.key, l.titre);
      localesParId[id] = (matiere: e.key, lecon: l);
    }
  }

  final fusion = <String, List<LessonModel>>{};
  final aEnvoyer = <LeconSyncDistante>[];
  final suppressions = Map<String, String>.from(suppressionsLocales);
  final traites = <String>{};
  var modifieLocal = false;

  void ajouterDansFusion(String matiere, LessonModel lecon) {
    final liste = fusion.putIfAbsent(matiere, () => []);
    final idx = liste.indexWhere((x) => x.titre == lecon.titre);
    if (idx >= 0) {
      liste[idx] = lecon;
    } else {
      liste.add(lecon);
    }
  }

  // 1. Parcourir les leçons distantes connues dans Firestore.
  for (final d in distantes.values) {
    traites.add(d.id);
    final loc = localesParId[d.id];
    final supLoc = suppressions[d.id];
    final modifLoc = modifsLocales[d.id];

    if (d.supprimee) {
      if (loc != null &&
          modifLoc != null &&
          modifLoc.compareTo(d.modifieLe) > 0) {
        // Ré-import local plus récent que la suppression distante.
        suppressions.remove(d.id);
        ajouterDansFusion(loc.matiere, loc.lecon);
        aEnvoyer.add(
          LeconSyncDistante(
            id: d.id,
            matiere: loc.matiere,
            lecon: loc.lecon,
            modifieLe: modifLoc,
            supprimee: false,
          ),
        );
      } else {
        if (loc != null) modifieLocal = true;
        if (supLoc == null || d.modifieLe.compareTo(supLoc) > 0) {
          suppressions[d.id] = d.modifieLe;
        }
      }
      continue;
    }

    // Leçon distante active.
    if (supLoc != null && supLoc.compareTo(d.modifieLe) >= 0) {
      // Suppression locale plus récente : on la propage vers Firestore.
      aEnvoyer.add(
        LeconSyncDistante(
          id: d.id,
          matiere: d.matiere,
          lecon: null,
          modifieLe: supLoc,
          supprimee: true,
        ),
      );
      if (loc != null) modifieLocal = true;
      continue;
    }

    suppressions.remove(d.id);
    final leconDist = d.lecon;
    if (leconDist == null) continue;

    if (loc != null) {
      final jsonLoc = jsonEncode(loc.lecon.toJson());
      final jsonDist = jsonEncode(leconDist.toJson());
      if (jsonLoc == jsonDist && loc.matiere == d.matiere) {
        ajouterDansFusion(loc.matiere, loc.lecon);
      } else if (modifLoc != null && modifLoc.compareTo(d.modifieLe) > 0) {
        ajouterDansFusion(loc.matiere, loc.lecon);
        aEnvoyer.add(
          LeconSyncDistante(
            id: d.id,
            matiere: loc.matiere,
            lecon: loc.lecon,
            modifieLe: modifLoc,
            supprimee: false,
          ),
        );
      } else {
        ajouterDansFusion(d.matiere, leconDist);
        modifieLocal = true;
      }
    } else {
      ajouterDansFusion(d.matiere, leconDist);
      modifieLocal = true;
    }
  }

  // 2. Leçons locales absentes de Firestore : à envoyer.
  for (final e in localesParId.entries) {
    if (traites.contains(e.key)) continue;
    suppressions.remove(e.key);
    ajouterDansFusion(e.value.matiere, e.value.lecon);
    aEnvoyer.add(
      LeconSyncDistante(
        id: e.key,
        matiere: e.value.matiere,
        lecon: e.value.lecon,
        modifieLe: modifsLocales[e.key] ?? now,
        supprimee: false,
      ),
    );
  }

  // 3. Suppressions locales qui ne sont pas encore dans Firestore.
  for (final e in suppressionsLocales.entries) {
    if (traites.contains(e.key)) continue;
    aEnvoyer.add(
      LeconSyncDistante(
        id: e.key,
        matiere: '',
        lecon: null,
        modifieLe: e.value,
        supprimee: true,
      ),
    );
  }

  return ResultatFusionLecons(
    localesFusionnees: fusion,
    aEnvoyer: aEnvoyer,
    suppressionsRestantes: suppressions,
    modifieLocalement: modifieLocal,
  );
}

/// Fusionne deux mémoires par question sans perdre le travail fait sur l'un ou
/// l'autre appareil.
Memoire fusionnerMemoires(
  Memoire locale,
  Memoire distante, {
  Horloge? horloge,
}) {
  final etatsLoc = locale.etats;
  final etatsDist = distante.etats;
  final cles = {...etatsLoc.keys, ...etatsDist.keys};
  final fusion = <String, EtatQuestion>{};

  for (final cle in cles) {
    final a = etatsLoc[cle];
    final b = etatsDist[cle];
    if (a == null) {
      fusion[cle] = b!;
    } else if (b == null) {
      fusion[cle] = a;
    } else {
      fusion[cle] = _meilleurEtat(a, b);
    }
  }
  return Memoire(horloge: horloge, etats: fusion);
}

EtatQuestion _meilleurEtat(EtatQuestion a, EtatQuestion b) {
  if (a.reps != b.reps) return a.reps > b.reps ? a : b;
  if (a.boite != b.boite) return a.boite > b.boite ? a : b;
  return a.retour.compareTo(b.retour) >= 0 ? a : b;
}

/// Enveloppe complète de la progression synchronisable dans `labo_progression/emile`.
class ProgressionSync {
  final int diamants;
  final String diamantsModifieLe;
  final String? resetLe;
  final String? derniereLeconImportee;
  final String? revisionDiamantsJour;
  final Map<String, List<bool>> etoiles;
  final Map<String, String> cartesDiamant;
  final Map<String, List<String>> seanceVus;
  final String memoireJson;
  final List<String> leconsBaseSupprimees;
  final List<String> questionsMasquees;

  const ProgressionSync({
    required this.diamants,
    required this.diamantsModifieLe,
    this.resetLe,
    this.derniereLeconImportee,
    this.revisionDiamantsJour,
    required this.etoiles,
    required this.cartesDiamant,
    required this.seanceVus,
    required this.memoireJson,
    this.leconsBaseSupprimees = const [],
    this.questionsMasquees = const [],
  });

  String toJsonString() {
    final clesEtoiles = etoiles.keys.toList()..sort();
    final clesCartes = cartesDiamant.keys.toList()..sort();
    final clesVus = seanceVus.keys.toList()..sort();
    final baseSuppr = List<String>.from(leconsBaseSupprimees)..sort();
    final masquees = List<String>.from(questionsMasquees)..sort();
    return jsonEncode({
      'v': 1,
      'diamants': diamants,
      'diamantsModifieLe': diamantsModifieLe,
      'resetLe': resetLe,
      'derniereLeconImportee': derniereLeconImportee,
      'revisionDiamantsJour': revisionDiamantsJour,
      'etoiles': {for (final k in clesEtoiles) k: etoiles[k]},
      'cartesDiamant': {for (final k in clesCartes) k: cartesDiamant[k]},
      'seanceVus': {
        for (final k in clesVus) k: (List<String>.from(seanceVus[k]!)..sort()),
      },
      'memoireJson': memoireJson,
      if (baseSuppr.isNotEmpty) 'leconsBaseSupprimees': baseSuppr,
      if (masquees.isNotEmpty) 'questionsMasquees': masquees,
    });
  }

  static ProgressionSync? tryFromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final diamants = (m['diamants'] as int?) ?? 0;
      final modifieLe = (m['diamantsModifieLe'] as String?) ?? '';
      final resetLe = m['resetLe'] as String?;
      final derniere = m['derniereLeconImportee'] as String?;
      final revJour = m['revisionDiamantsJour'] as String?;

      final etoiles = <String, List<bool>>{};
      final rawEtoiles = m['etoiles'];
      if (rawEtoiles is Map) {
        for (final e in rawEtoiles.entries) {
          if (e.key is String && e.value is List) {
            final vals = (e.value as List).map((x) => x == true).toList();
            while (vals.length < 3) {
              vals.add(false);
            }
            etoiles[e.key as String] = vals.take(3).toList();
          }
        }
      }

      final cartes = <String, String>{};
      final rawCartes = m['cartesDiamant'];
      if (rawCartes is Map) {
        for (final e in rawCartes.entries) {
          if (e.key is String && e.value is String) {
            cartes[e.key as String] = e.value as String;
          }
        }
      }

      final vus = <String, List<String>>{};
      final rawVus = m['seanceVus'];
      if (rawVus is Map) {
        for (final e in rawVus.entries) {
          if (e.key is String && e.value is List) {
            vus[e.key as String] = [
              for (final item in (e.value as List)) item.toString(),
            ];
          }
        }
      }

      final mem = (m['memoireJson'] as String?) ?? Memoire().toJsonString();
      final baseSuppr = <String>[
        if (m['leconsBaseSupprimees'] is List)
          for (final item in (m['leconsBaseSupprimees'] as List))
            item.toString(),
      ];
      final masquees = <String>[
        if (m['questionsMasquees'] is List)
          for (final item in (m['questionsMasquees'] as List)) item.toString(),
      ];
      return ProgressionSync(
        diamants: diamants < 0 ? 0 : diamants,
        diamantsModifieLe: modifieLe,
        resetLe: resetLe,
        derniereLeconImportee: derniere,
        revisionDiamantsJour: revJour,
        etoiles: etoiles,
        cartesDiamant: cartes,
        seanceVus: vus,
        memoireJson: mem,
        leconsBaseSupprimees: baseSuppr,
        questionsMasquees: masquees,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Résultat de la fusion de la progression entre cet appareil et Firestore.
class ResultatFusionProgression {
  final ProgressionSync fusionnee;
  final bool doitEnvoyer;
  final bool modifieLocalement;

  const ResultatFusionProgression({
    required this.fusionnee,
    required this.doitEnvoyer,
    required this.modifieLocalement,
  });
}

String? _maxDateStr(String? a, String? b) {
  if (a == null || a.isEmpty) return b;
  if (b == null || b.isEmpty) return a;
  final pa = _analyserDateSimple(a);
  final pb = _analyserDateSimple(b);
  if (pa != null && pb != null) {
    return pa.isBefore(pb) ? b : a;
  }
  return a.compareTo(b) >= 0 ? a : b;
}

DateTime? _analyserDateSimple(String s) {
  final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

ResultatFusionProgression fusionnerProgression(
  ProgressionSync locale,
  ProgressionSync? distante, {
  Horloge? horloge,
}) {
  if (distante == null) {
    return ResultatFusionProgression(
      fusionnee: locale,
      doitEnvoyer: true,
      modifieLocalement: false,
    );
  }

  final resetLoc = locale.resetLe;
  final resetDist = distante.resetLe;
  final resetLocGagne =
      resetLoc != null &&
      (resetDist == null || resetLoc.compareTo(resetDist) > 0) &&
      resetLoc.compareTo(distante.diamantsModifieLe) > 0;
  if (resetLocGagne) {
    return ResultatFusionProgression(
      fusionnee: locale,
      doitEnvoyer: true,
      modifieLocalement: false,
    );
  }

  final resetDistGagne =
      resetDist != null &&
      (resetLoc == null || resetDist.compareTo(resetLoc) > 0) &&
      resetDist.compareTo(locale.diamantsModifieLe) > 0;
  if (resetDistGagne) {
    return ResultatFusionProgression(
      fusionnee: distante,
      doitEnvoyer: false,
      modifieLocalement: locale.toJsonString() != distante.toJsonString(),
    );
  }

  final diamants = locale.diamants >= distante.diamants
      ? locale.diamants
      : distante.diamants;
  final modifieLe = _maxDateStr(
        locale.diamantsModifieLe,
        distante.diamantsModifieLe,
      ) ??
      '';
  final resetLe = _maxDateStr(resetLoc, resetDist);

  final etoiles = <String, List<bool>>{};
  for (final k in {...locale.etoiles.keys, ...distante.etoiles.keys}) {
    final a = locale.etoiles[k] ?? const [false, false, false];
    final b = distante.etoiles[k] ?? const [false, false, false];
    etoiles[k] = [
      (a.isNotEmpty && a[0]) || (b.isNotEmpty && b[0]),
      (a.length > 1 && a[1]) || (b.length > 1 && b[1]),
      (a.length > 2 && a[2]) || (b.length > 2 && b[2]),
    ];
  }

  final cartesDiamant = <String, String>{};
  for (final k in {
    ...locale.cartesDiamant.keys,
    ...distante.cartesDiamant.keys,
  }) {
    final d = _maxDateStr(locale.cartesDiamant[k], distante.cartesDiamant[k]);
    if (d != null) cartesDiamant[k] = d;
  }

  final seanceVus = <String, List<String>>{};
  for (final k in {...locale.seanceVus.keys, ...distante.seanceVus.keys}) {
    final s = {
      ...?locale.seanceVus[k],
      ...?distante.seanceVus[k],
    }.toList()
      ..sort();
    seanceVus[k] = s;
  }

  final memLoc = Memoire.lire(locale.memoireJson, horloge: horloge).memoire;
  final memDist = Memoire.lire(distante.memoireJson, horloge: horloge).memoire;
  final memFusion = fusionnerMemoires(memLoc, memDist, horloge: horloge);

  final revJour = _maxDateStr(
    locale.revisionDiamantsJour,
    distante.revisionDiamantsJour,
  );
  final derniere =
      distante.diamantsModifieLe.compareTo(locale.diamantsModifieLe) > 0 &&
              distante.derniereLeconImportee != null
          ? distante.derniereLeconImportee
          : (locale.derniereLeconImportee ?? distante.derniereLeconImportee);

  final baseSuppr = {
    ...locale.leconsBaseSupprimees,
    ...distante.leconsBaseSupprimees,
  }.toList()
    ..sort();
  final masquees = {
    ...locale.questionsMasquees,
    ...distante.questionsMasquees,
  }.toList()
    ..sort();

  final fusionnee = ProgressionSync(
    diamants: diamants,
    diamantsModifieLe: modifieLe,
    resetLe: resetLe,
    derniereLeconImportee: derniere,
    revisionDiamantsJour: revJour,
    etoiles: etoiles,
    cartesDiamant: cartesDiamant,
    seanceVus: seanceVus,
    memoireJson: memFusion.toJsonString(),
    leconsBaseSupprimees: baseSuppr,
    questionsMasquees: masquees,
  );

  final jsonFusion = fusionnee.toJsonString();
  return ResultatFusionProgression(
    fusionnee: fusionnee,
    doitEnvoyer: jsonFusion != distante.toJsonString(),
    modifieLocalement: jsonFusion != locale.toJsonString(),
  );
}

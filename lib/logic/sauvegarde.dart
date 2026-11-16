import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lesson_model.dart';
import 'accueil_logic.dart';
import 'memoire.dart';

/// Sauvegarde / restauration locale de la progression (texte JSON).
///
/// INCLUS : diamants, étoiles par leçon (`<titre>_star_*`), leçons importées
/// (`custom_lessons`), mémoire par question (`memoire_v1`), réglages (sons,
/// vibrations, chrono), `seance_vus_*`, `cartes_diamant_*`,
/// `derniere_lecon_importee`, `revision_diamants_jour`.
/// EXCLU : le code parent (`parent_pin`) et tout ce qui n'est pas listé ici.
/// Le niveau est calculé à partir des diamants ; le combo n'est pas conservé
/// (il repart de zéro à chaque lancement).
const int kSauvegardeVersion = 1;

/// Clé de la copie de secours faite juste avant d'écraser.
const String kCleAvantRestauration = 'sauvegarde_avant_restauration';

enum _Type { entier, booleen, texte, listeTextes }

const Map<String, _Type> _clesFixes = {
  'emile_diamonds': _Type.entier,
  'custom_lessons': _Type.texte,
  'memoire_v1': _Type.texte,
  'reglage_sons': _Type.booleen,
  'reglage_vibrations': _Type.booleen,
  'reglage_chrono_secondes': _Type.entier,
  'derniere_lecon_importee': _Type.texte,
  'revision_diamants_jour': _Type.texte,
};

/// (préfixe ou suffixe, type) des clés dont le nom contient un titre de leçon.
_Type? _typeDe(String cle) {
  final fixe = _clesFixes[cle];
  if (fixe != null) return fixe;
  if (cle.startsWith('seance_vus_')) return _Type.listeTextes;
  if (cle.startsWith('cartes_diamant_')) return _Type.texte;
  if (cle.endsWith('_star_astuces') ||
      cle.endsWith('_star_train') ||
      cle.endsWith('_star_quiz')) {
    return _Type.booleen;
  }
  return null;
}

/// Vrai si [cle] fait partie de ce qu'une sauvegarde contient.
bool cleSauvegardee(String cle) => _typeDe(cle) != null;

bool _typeOk(_Type t, Object? v) => switch (t) {
  _Type.entier => v is int,
  _Type.booleen => v is bool,
  _Type.texte => v is String,
  _Type.listeTextes => v is List && v.every((e) => e is String),
};

/// Construit le texte de sauvegarde à partir de toutes les valeurs stockées.
String construireSauvegarde(Map<String, Object> valeurs, {DateTime? date}) {
  final prefs = <String, Object>{};
  for (final cle in valeurs.keys.toList()..sort()) {
    if (cleSauvegardee(cle)) {
      final v = valeurs[cle]!;
      prefs[cle] = v is List ? List<String>.from(v) : v;
    }
  }
  return jsonEncode({
    'sauvegardeVersion': kSauvegardeVersion,
    'date': (date ?? DateTime.now()).toIso8601String(),
    'prefs': prefs,
  });
}

/// Sauvegarde vérifiée, prête à être appliquée.
class SauvegardeValide {
  final Map<String, Object> valeurs;
  final int nbLecons;
  final int diamants;
  final int niveau;
  const SauvegardeValide(this.valeurs, this.nbLecons, this.diamants, this.niveau);

  String get resume =>
      "$nbLecons leçon${nbLecons > 1 ? 's' : ''} importée${nbLecons > 1 ? 's' : ''}, "
      "niveau $niveau, $diamants diamant${diamants > 1 ? 's' : ''}";
}

/// Vérifie le texte. Lance une [FormatException] (message en français) à la
/// moindre anomalie ; ne modifie rien.
SauvegardeValide validerSauvegarde(String texte) {
  final Object? brut;
  try {
    brut = jsonDecode(texte.trim());
  } catch (_) {
    throw const FormatException("Ce texte n'est pas une sauvegarde valide.");
  }
  if (brut is! Map) {
    throw const FormatException("Ce texte n'est pas une sauvegarde valide.");
  }
  if (brut['sauvegardeVersion'] != kSauvegardeVersion) {
    throw const FormatException(
      "Version de sauvegarde inconnue : impossible de la restaurer.",
    );
  }
  final p = brut['prefs'];
  if (p is! Map) {
    throw const FormatException("La sauvegarde est incomplète.");
  }
  final valeurs = <String, Object>{};
  for (final e in p.entries) {
    final cle = e.key;
    final v = e.value;
    if (cle is! String) {
      throw const FormatException("La sauvegarde est abîmée.");
    }
    final t = _typeDe(cle);
    if (t == null) continue; // clé inconnue (ou parent_pin) : ignorée
    if (v == null || !_typeOk(t, v)) {
      throw FormatException("Valeur incorrecte pour « $cle ».");
    }
    valeurs[cle] = v is List ? List<String>.from(v) : v as Object;
  }

  var nbLecons = 0;
  final custom = valeurs['custom_lessons'] as String?;
  if (custom != null) {
    try {
      final m = jsonDecode(custom) as Map<String, dynamic>;
      for (final l in m.values) {
        for (final j in (l as List)) {
          LessonModel.fromJson(j as Map<String, dynamic>);
          nbLecons++;
        }
      }
    } catch (_) {
      throw const FormatException("Les leçons de la sauvegarde sont illisibles.");
    }
  }
  final memoire = valeurs['memoire_v1'] as String?;
  if (memoire != null && Memoire.lire(memoire).corrompue) {
    throw const FormatException("La mémoire de la sauvegarde est illisible.");
  }
  final diamants = (valeurs['emile_diamonds'] as int?) ?? 0;
  if (diamants < 0) {
    throw const FormatException("Valeur incorrecte pour « emile_diamonds ».");
  }
  return SauvegardeValide(valeurs, nbLecons, diamants, niveauPour(diamants));
}

/// Relève dans [prefs] toutes les valeurs que la sauvegarde contient.
Map<String, Object> valeursSauvegardables(SharedPreferences prefs) {
  final r = <String, Object>{};
  for (final cle in prefs.getKeys()) {
    if (!cleSauvegardee(cle)) continue;
    final v = prefs.get(cle);
    if (v != null) r[cle] = v;
  }
  return r;
}

/// Texte de sauvegarde de l'état actuel.
Future<String> sauvegardeActuelle([SharedPreferences? p]) async {
  final prefs = p ?? await SharedPreferences.getInstance();
  return construireSauvegarde(valeursSauvegardables(prefs));
}

/// Applique une sauvegarde déjà validée : copie de secours de l'état actuel
/// dans [kCleAvantRestauration], puis remplacement exact du contenu
/// sauvegardé (les clés absentes de la sauvegarde sont retirées). Le code
/// parent et tout le reste ne sont pas touchés.
Future<void> appliquerSauvegarde(
  SauvegardeValide s, [
  SharedPreferences? p,
]) async {
  final prefs = p ?? await SharedPreferences.getInstance();
  await prefs.setString(kCleAvantRestauration, await sauvegardeActuelle(prefs));
  for (final cle in prefs.getKeys().toList()) {
    if (cleSauvegardee(cle) && !s.valeurs.containsKey(cle)) {
      await prefs.remove(cle);
    }
  }
  for (final e in s.valeurs.entries) {
    final v = e.value;
    if (v is int) {
      await prefs.setInt(e.key, v);
    } else if (v is bool) {
      await prefs.setBool(e.key, v);
    } else if (v is String) {
      await prefs.setString(e.key, v);
    } else if (v is List<String>) {
      await prefs.setStringList(e.key, v);
    }
  }
}

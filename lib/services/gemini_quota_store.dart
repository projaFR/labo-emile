import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Estimation locale de l'utilisation quotidienne de l'API gratuite Gemini.
/// L'API REST Gemini ne fournit pas de pourcentage de quota restant global ;
/// on suit donc les appels, leçons générées, jetons (`usageMetadata`) et
/// éventuels dépassements (HTTP 429) pour la journée en cours.
class UtilisationGeminiJour {
  static const int kQuotaIndicatifJour = 20;

  final String jour;
  final int appels;
  final int lecons;
  final int jetons;
  final bool limiteAtteinte;

  const UtilisationGeminiJour({
    required this.jour,
    this.appels = 0,
    this.lecons = 0,
    this.jetons = 0,
    this.limiteAtteinte = false,
  });

  int get restantIndicatif {
    if (limiteAtteinte) return 0;
    final r = kQuotaIndicatifJour - appels;
    return r < 0 ? 0 : r;
  }

  /// Proportion restante entre 0.0 et 1.0 pour la jauge visuelle.
  double get ratioRestant {
    if (limiteAtteinte) return 0.0;
    return (restantIndicatif / kQuotaIndicatifJour).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
    'jour': jour,
    'appels': appels,
    'lecons': lecons,
    'jetons': jetons,
    'limiteAtteinte': limiteAtteinte,
  };

  factory UtilisationGeminiJour.fromJson(
    Map<String, dynamic> m,
    String jourActuel,
  ) {
    if (m['jour'] != jourActuel) {
      return UtilisationGeminiJour(jour: jourActuel);
    }
    return UtilisationGeminiJour(
      jour: jourActuel,
      appels: (m['appels'] as int?) ?? 0,
      lecons: (m['lecons'] as int?) ?? 0,
      jetons: (m['jetons'] as int?) ?? 0,
      limiteAtteinte: m['limiteAtteinte'] == true,
    );
  }
}

class GeminiQuotaStore {
  static const String _clePrefs = 'gemini_quota_jour_v1';

  static String jourAujourdhui([DateTime? maintenant]) {
    final d = maintenant ?? DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final j = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$j';
  }

  static Future<UtilisationGeminiJour> charger() async {
    final prefs = await SharedPreferences.getInstance();
    final auj = jourAujourdhui();
    final raw = prefs.getString(_clePrefs);
    if (raw == null || raw.isEmpty) {
      return UtilisationGeminiJour(jour: auj);
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return UtilisationGeminiJour.fromJson(decoded, auj);
    } catch (_) {
      return UtilisationGeminiJour(jour: auj);
    }
  }

  static Future<UtilisationGeminiJour> enregistrer({
    int appelsAjoutes = 0,
    int leconsAjoutees = 0,
    int jetonsAjoutes = 0,
    bool limiteAtteinte = false,
  }) async {
    final actuel = await charger();
    final maj = UtilisationGeminiJour(
      jour: actuel.jour,
      appels: actuel.appels + appelsAjoutes,
      lecons: actuel.lecons + leconsAjoutees,
      jetons: actuel.jetons + jetonsAjoutes,
      limiteAtteinte: actuel.limiteAtteinte || limiteAtteinte,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clePrefs, jsonEncode(maj.toJson()));
    return maj;
  }
}

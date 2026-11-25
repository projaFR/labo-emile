import 'package:shared_preferences/shared_preferences.dart';

export 'gemini_lecon_service.dart' show masquerCleGemini;

/// Clé de stockage local pour la clé API Gemini gratuite.
/// Volontairement absente de `sauvegarde.dart` : ne sort jamais dans les
/// sauvegardes partagées et n'est jamais envoyée sur GitHub.
const String kCleGeminiPrefs = 'gemini_api_key';
const String kModeleGeminiPrefs = 'gemini_modele_prefere';

/// Lit la clé Gemini enregistrée localement (`null` si absente ou vide).
Future<String?> lireCleGemini([SharedPreferences? p]) async {
  final prefs = p ?? await SharedPreferences.getInstance();
  final val = prefs.getString(kCleGeminiPrefs)?.trim();
  if (val == null || val.isEmpty) return null;
  return val;
}

/// Enregistre ou efface (si vide) la clé Gemini localement.
Future<void> enregistrerCleGemini(String cle, [SharedPreferences? p]) async {
  final prefs = p ?? await SharedPreferences.getInstance();
  final propre = cle.trim();
  if (propre.isEmpty) {
    await prefs.remove(kCleGeminiPrefs);
  } else {
    await prefs.setString(kCleGeminiPrefs, propre);
  }
}

/// Lit le modèle Gemini choisi par le parent (`null` = mode automatique).
Future<String?> lireModeleGeminiPrefere([SharedPreferences? p]) async {
  final prefs = p ?? await SharedPreferences.getInstance();
  final val = prefs.getString(kModeleGeminiPrefs)?.trim();
  if (val == null || val.isEmpty) return null;
  return val;
}

/// Enregistre ou efface (`null` = automatique) le modèle Gemini préféré.
Future<void> enregistrerModeleGeminiPrefere(
  String? modele, [
  SharedPreferences? p,
]) async {
  final prefs = p ?? await SharedPreferences.getInstance();
  final propre = modele?.trim() ?? '';
  if (propre.isEmpty) {
    await prefs.remove(kModeleGeminiPrefs);
  } else {
    await prefs.setString(kModeleGeminiPrefs, propre);
  }
}

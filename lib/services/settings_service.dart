import 'package:shared_preferences/shared_preferences.dart';

/// Réglages parent : sons, vibrations, temps du Défi Chrono.
/// Valeurs gardées en mémoire (lecture synchrone) et sauvegardées.
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String kSons = 'reglage_sons';
  static const String kVibrations = 'reglage_vibrations';
  static const String kChrono = 'reglage_chrono_secondes';

  /// Valeurs permises pour le chrono : 0 = sans, 15 s, 30 s.
  static const List<int> chronoPermis = [0, 15, 30];

  bool sons = true;
  bool vibrations = true;
  int chronoSecondes = 30;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    sons = prefs.getBool(kSons) ?? true;
    vibrations = prefs.getBool(kVibrations) ?? true;
    final c = prefs.getInt(kChrono) ?? 30;
    chronoSecondes = chronoPermis.contains(c) ? c : 30;
  }

  Future<void> setSons(bool v) async {
    sons = v;
    (await SharedPreferences.getInstance()).setBool(kSons, v);
  }

  Future<void> setVibrations(bool v) async {
    vibrations = v;
    (await SharedPreferences.getInstance()).setBool(kVibrations, v);
  }

  Future<void> setChrono(int s) async {
    chronoSecondes = chronoPermis.contains(s) ? s : 30;
    (await SharedPreferences.getInstance()).setInt(kChrono, chronoSecondes);
  }
}

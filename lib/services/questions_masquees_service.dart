import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'labo_sync_service.dart';

/// Questions signalées/masquées par le parent (ex. erreur de l'IA).
class QuestionsMasqueesService extends ChangeNotifier {
  static final QuestionsMasqueesService _instance =
      QuestionsMasqueesService._();
  factory QuestionsMasqueesService() => _instance;
  QuestionsMasqueesService._();

  static const String kCle = 'questions_masquees_v1';

  Set<String> _masquees = {};
  bool _chargee = false;

  Set<String> get masquees => Set.unmodifiable(_masquees);
  bool estMasquee(String cle) => _masquees.contains(cle);

  Future<void> charger({bool forcer = false}) async {
    if (_chargee && !forcer) return;
    final prefs = await SharedPreferences.getInstance();
    _masquees = (prefs.getStringList(kCle) ?? const []).toSet();
    _chargee = true;
    notifyListeners();
  }

  Future<void> masquer(String cle) async {
    if (_masquees.contains(cle)) return;
    _masquees = {..._masquees, cle};
    await _enregistrer();
  }

  Future<void> demasquer(String cle) async {
    if (!_masquees.contains(cle)) return;
    _masquees = {..._masquees}..remove(cle);
    await _enregistrer();
  }

  Future<void> _enregistrer() async {
    final prefs = await SharedPreferences.getInstance();
    final liste = _masquees.toList()..sort();
    if (liste.isEmpty) {
      await prefs.remove(kCle);
    } else {
      await prefs.setStringList(kCle, liste);
    }
    notifyListeners();
    LaboSyncService().signalerChangementLocal();
  }
}

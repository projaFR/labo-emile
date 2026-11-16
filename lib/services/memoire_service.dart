import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logic/memoire.dart';

/// Garde la mémoire par question dans SharedPreferences.
///
/// - Tout tient dans UNE clé versionnée ([kCle]), écrite d'un seul coup
///   (le JSON complet est construit, puis un seul `setString`).
/// - Si la lecture échoue, l'ancien texte brut est copié dans une clé de
///   secours ([kCleCorrompue]) AVANT de repartir d'une mémoire vide : on ne
///   perd jamais la progression en silence.
class MemoireService extends ChangeNotifier {
  static final MemoireService _instance = MemoireService._internal();
  factory MemoireService() => _instance;
  MemoireService._internal();

  static const String kCle = 'memoire_v1';
  static const String kCleCorrompue = 'memoire_v1_corrompue';

  Memoire memoire = Memoire();

  /// Vrai si un texte illisible a été mis de côté au dernier chargement.
  bool secoursCree = false;

  /// Appelé après chaque nouvelle réponse enregistrée localement.
  VoidCallback? onModification;

  Future<void>? _chargement;
  Future<void> _ecriture = Future.value();

  /// Charge la mémoire (une seule fois ; les appels suivants attendent le
  /// même chargement). [forcer] recharge depuis le stockage.
  Future<void> charger({bool forcer = false}) {
    if (forcer) _chargement = null;
    return _chargement ??= _charger();
  }

  Future<void> _charger() async {
    secoursCree = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(kCle);
      final lecture = Memoire.lire(brut);
      memoire = lecture.memoire;
      if (lecture.corrompue && brut != null) {
        await _mettreDeCote(prefs, brut);
        secoursCree = true;
      }
    } catch (_) {
      memoire = Memoire();
    }
    notifyListeners();
  }

  /// Copie le texte illisible dans la première clé de secours libre.
  Future<void> _mettreDeCote(SharedPreferences prefs, String brut) async {
    var cle = kCleCorrompue;
    var n = 1;
    while (prefs.containsKey(cle)) {
      if (prefs.getString(cle) == brut) return;
      n++;
      cle = '${kCleCorrompue}_$n';
    }
    await prefs.setString(cle, brut);
  }

  /// Enregistre la réponse à une question et sauvegarde.
  Future<void> enregistrer(String cle, Resultat r) async {
    await charger();
    memoire.enregistrer(cle, r);
    notifyListeners();
    await _sauver();
    onModification?.call();
  }

  /// Efface la mémoire par question (ne touche à rien d'autre : ni diamants,
  /// ni étoiles, ni leçons).
  Future<void> reinitialiser() async {
    await charger();
    memoire.reinitialiser();
    notifyListeners();
    await _sauver();
  }

  Future<void> _sauver() {
    _ecriture = _ecriture.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kCle, memoire.toJsonString());
      } catch (_) {}
    });
    return _ecriture;
  }
}

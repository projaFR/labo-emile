import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import '../logic/sync_logic.dart';
import '../models/lesson_model.dart';
import 'labo_firebase_auth.dart';
import 'labo_firestore_client.dart';
import 'labo_sync_plateforme.dart';
import 'memoire_service.dart';
import 'questions_masquees_service.dart';

enum EtatSyncLabo { nonConfigure, synchronisation, aJour, horsLigne, erreur }

/// Service singleton qui synchronise les leçons et la progression d'Émile
/// avec Firestore (`labo_lecons` et `labo_progression/emile`) sans aucune DLL.
class LaboSyncService extends ChangeNotifier {
  static final LaboSyncService _instance = LaboSyncService._internal();
  factory LaboSyncService() => _instance;
  LaboSyncService._internal();

  /// Clés privées : absentes de `sauvegarde.dart` (jamais exportées).
  static const String kCleSessionFirebase = 'labo_firebase_session';
  static const String kCleMetaSync = 'labo_sync_meta';
  static const String kCleOAuthFirebase = 'labo_firebase_oauth';

  static const MethodChannel _canalPlateforme =
      MethodChannel('fr.thibaut.laboemile/photo');

  final http.Client _httpClient = http.Client();
  late final LaboFirebaseAuth _auth = LaboFirebaseAuth(
    lireStockage: () async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(kCleSessionFirebase);
    },
    ecrireStockage: (val) async {
      final prefs = await SharedPreferences.getInstance();
      if (val == null) {
        await prefs.remove(kCleSessionFirebase);
      } else {
        await prefs.setString(kCleSessionFirebase, val);
      }
    },
    client: _httpClient,
  );

  EtatSyncLabo _etat = EtatSyncLabo.nonConfigure;
  String? _erreur;
  String? _derniereSyncLe;
  int _revisionLocale = 0;

  bool _initialise = false;
  bool _enCours = false;
  bool _relancer = false;
  Timer? _debounce;
  Future<void> _metaQueue = Future.value();

  EtatSyncLabo get etat => _etat;
  String? get erreur => _erreur;
  String? get derniereSyncLe => _derniereSyncLe;
  int get revisionLocale => _revisionLocale;
  bool get estConfigure => _auth.estConnecte;
  String? get emailCompte => _auth.config?.email;
  String get projectIdActuel => _auth.config?.projectId ?? 'reviser-bdd1a';
  String get webApiKeyActuelle => _auth.config?.webApiKey ?? '';

  String get libelleEtat => switch (_etat) {
    EtatSyncLabo.nonConfigure =>
      'Non configurée (tout reste sur cet appareil).',
    EtatSyncLabo.synchronisation => 'Synchronisation en cours…',
    EtatSyncLabo.aJour => _auth.config != null
        ? 'Synchronisé (${_auth.config!.email})'
        : 'Synchronisé',
    EtatSyncLabo.horsLigne =>
      'Hors ligne : les progrès partiront au retour du réseau.',
    EtatSyncLabo.erreur => _erreur ?? 'Erreur de synchronisation.',
  };

  Future<void> initialiser() async {
    if (_initialise) return;
    _initialise = true;
    MemoireService().onModification = () => signalerChangementLocal();
    var cfg = await _auth.charger();

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _canalPlateforme.setMethodCallHandler((call) async {
        if (call.method == 'sessionUsbDisponible') {
          final raw = call.arguments as String?;
          if (raw != null && raw.trim().isNotEmpty) {
            await _appliquerSessionUsbB64(raw, lancerSynchro: true);
            try {
              await _canalPlateforme.invokeMethod<String>(
                'consommerSessionUsb',
              );
            } catch (_) {}
          }
        }
      });
      try {
        final b64 = await _canalPlateforme.invokeMethod<String>(
          'consommerSessionUsb',
        );
        if (b64 != null && b64.trim().isNotEmpty) {
          await _appliquerSessionUsbB64(b64, lancerSynchro: false);
          cfg = _auth.config;
        }
      } catch (_) {}
    }

    final meta = await _lireMeta();
    _derniereSyncLe = meta.derniereSyncLe;
    _etat = cfg == null ? EtatSyncLabo.nonConfigure : EtatSyncLabo.aJour;
    notifyListeners();
  }

  Future<void> _appliquerSessionUsbB64(
    String b64, {
    required bool lancerSynchro,
  }) async {
    try {
      final jsonStr = utf8.decode(
        base64Url.decode(base64Url.normalize(b64.trim())),
      );
      final session = ConfigFirebaseLabo.tryParse(jsonStr);
      if (session == null) return;
      await _auth.importerSession(session);
      if (session.desktopClientId != null &&
          session.desktopClientSecret != null) {
        final oauth = ConfigOAuthGoogleLabo(
          projectId: session.projectId,
          webApiKey: session.webApiKey,
          desktopClientId: session.desktopClientId!,
          desktopClientSecret: session.desktopClientSecret!,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kCleOAuthFirebase, jsonEncode(oauth.toJson()));
      }
      _etat = EtatSyncLabo.aJour;
      _erreur = null;
      notifyListeners();
      if (lancerSynchro) {
        unawaited(synchroniserMaintenant());
      }
    } catch (_) {}
  }

  Future<ConfigOAuthGoogleLabo?> detecterConfigOAuth() async {
    final cfg = _auth.config;
    if (cfg != null &&
        cfg.desktopClientId != null &&
        cfg.desktopClientSecret != null) {
      return ConfigOAuthGoogleLabo(
        projectId: cfg.projectId,
        webApiKey: cfg.webApiKey,
        desktopClientId: cfg.desktopClientId!,
        desktopClientSecret: cfg.desktopClientSecret!,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = ConfigOAuthGoogleLabo.tryParse(
      prefs.getString(kCleOAuthFirebase),
    );
    if (saved != null) return saved;
    return chargerConfigOAuthDepuisReviser();
  }

  Future<void> connecterAvecGoogle({String? jsonConfigManuel}) async {
    await initialiser();
    final ConfigOAuthGoogleLabo? oauth;
    if (jsonConfigManuel != null && jsonConfigManuel.trim().isNotEmpty) {
      oauth = ConfigOAuthGoogleLabo.tryParse(jsonConfigManuel);
      if (oauth == null) {
        throw const ErreurSyncLabo(
          'Contenu JSON firebase_config.json invalide ou incomplet.',
        );
      }
    } else {
      oauth = await detecterConfigOAuth();
      if (oauth == null) {
        throw const ErreurSyncLabo(
          'Colle le contenu de firebase_config.json (ou connecte d’abord le PC puis utilise le transfert USB).',
        );
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kCleOAuthFirebase, jsonEncode(oauth.toJson()));

    _debounce?.cancel();
    _erreur = null;
    _etat = EtatSyncLabo.synchronisation;
    notifyListeners();

    try {
      final idToken = await obtenirIdTokenGoogleLoopback(
        oauthConfig: oauth,
        ouvrirNavigateur: _ouvrirUrlNavigateur,
        client: _httpClient,
      );
      await _auth.connecterAvecGoogleIdToken(
        projectId: oauth.projectId,
        webApiKey: oauth.webApiKey,
        googleIdToken: idToken,
        desktopClientId: oauth.desktopClientId,
        desktopClientSecret: oauth.desktopClientSecret,
      );
    } on ErreurSyncLabo catch (e) {
      _erreur = e.message;
      _etat = e.horsLigne ? EtatSyncLabo.horsLigne : EtatSyncLabo.erreur;
      notifyListeners();
      rethrow;
    } catch (_) {
      const msg = 'La connexion Google a échoué.';
      _erreur = msg;
      _etat = EtatSyncLabo.erreur;
      notifyListeners();
      throw const ErreurSyncLabo(msg);
    }

    final ok = await synchroniserMaintenant();
    if (!ok) {
      throw ErreurSyncLabo(
        _erreur ?? 'Connexion réussie, mais Firestore a refusé la synchro.',
        horsLigne: _etat == EtatSyncLabo.horsLigne,
      );
    }
  }

  Future<bool> _ouvrirUrlNavigateur(Uri url) => ouvrirNavigateurOAuth(url, (
    u,
  ) async {
    try {
      final ok = await _canalPlateforme.invokeMethod<bool>('ouvrirUrl', {
        'url': u.toString(),
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  });

  /// Code texte à copier depuis le PC pour connecter un iPad / navigateur (Option A).
  String? exporterCodeConnexionIpad() {
    final cfg = _auth.config;
    if (cfg == null) return null;
    final b64 = base64UrlEncode(
      utf8.encode(jsonEncode(cfg.toJson())),
    ).replaceAll('=', '');
    return 'LABO1:$b64';
  }

  /// Connecte cet appareil (ex. iPad Safari) à partir du code copié depuis le PC.
  Future<void> connecterAvecCodeIpad(String saisie) async {
    await initialiser();
    var propre = saisie.replaceAll(RegExp(r'\s+'), '');
    if (propre.startsWith('LABO1:')) {
      propre = propre.substring('LABO1:'.length);
    }
    ConfigFirebaseLabo? session;
    try {
      final jsonStr = utf8.decode(base64Url.decode(base64Url.normalize(propre)));
      session = ConfigFirebaseLabo.tryParse(jsonStr);
    } catch (_) {
      session = null;
    }
    if (session == null) {
      throw const ErreurSyncLabo(
        'Code de connexion invalide. Copie-le à nouveau depuis le PC.',
      );
    }

    _debounce?.cancel();
    _erreur = null;
    await _auth.importerSession(session);
    if (session.desktopClientId != null &&
        session.desktopClientSecret != null) {
      final oauth = ConfigOAuthGoogleLabo(
        projectId: session.projectId,
        webApiKey: session.webApiKey,
        desktopClientId: session.desktopClientId!,
        desktopClientSecret: session.desktopClientSecret!,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kCleOAuthFirebase, jsonEncode(oauth.toJson()));
    }
    _etat = EtatSyncLabo.synchronisation;
    notifyListeners();

    final ok = await synchroniserMaintenant();
    if (!ok) {
      throw ErreurSyncLabo(
        _erreur ?? 'Code accepté, mais Firestore a refusé la synchro.',
        horsLigne: _etat == EtatSyncLabo.horsLigne,
      );
    }
  }

  /// Sur Windows, pousse directement la session connectée vers le téléphone USB.
  Future<({bool ok, String message})> envoyerSessionAuTelephoneUsb() async {
    final cfg = _auth.config;
    if (cfg == null) {
      return (ok: false, message: 'Connecte d’abord le compte sur le PC.');
    }
    final b64 = base64UrlEncode(
      utf8.encode(jsonEncode(cfg.toJson())),
    ).replaceAll('=', '');
    return envoyerSessionUsbAdb(b64);
  }

  Future<void> connecterCompte({
    required String projectId,
    required String webApiKey,
    required String email,
    required String motDePasse,
  }) async {
    await initialiser();
    _debounce?.cancel();
    _erreur = null;
    _etat = EtatSyncLabo.synchronisation;
    notifyListeners();
    try {
      await _auth.connecter(
        projectId: projectId,
        webApiKey: webApiKey,
        email: email,
        motDePasse: motDePasse,
      );
    } on ErreurSyncLabo catch (e) {
      _erreur = e.message;
      _etat = e.horsLigne ? EtatSyncLabo.horsLigne : EtatSyncLabo.erreur;
      notifyListeners();
      rethrow;
    }

    final ok = await synchroniserMaintenant();
    if (!ok) {
      throw ErreurSyncLabo(
        _erreur ?? 'Connexion réussie, mais Firestore a refusé la synchro.',
        horsLigne: _etat == EtatSyncLabo.horsLigne,
      );
    }
  }

  Future<void> deconnecterCompte() async {
    _debounce?.cancel();
    await _auth.deconnecter();
    _erreur = null;
    _etat = EtatSyncLabo.nonConfigure;
    notifyListeners();
  }

  void signalerChangementLocal({
    bool remiseAZero = false,
    String? matiereAjoutee,
    String? titreAjoute,
  }) {
    unawaited(
      _enregistrerModifLocale(
        remiseAZero: remiseAZero,
        matiereAjoutee: matiereAjoutee,
        titreAjoute: titreAjoute,
      ),
    );
  }

  void signalerSuppressionLecon(String matiere, String titre) {
    unawaited(_enregistrerSuppression(matiere, titre));
  }

  Future<void> _enregistrerModifLocale({
    required bool remiseAZero,
    String? matiereAjoutee,
    String? titreAjoute,
  }) {
    _metaQueue = _metaQueue.then((_) async {
      final now = DateTime.now().toUtc().toIso8601String();
      final meta = await _lireMeta();
      meta.diamantsModifieLe = now;
      if (remiseAZero) {
        meta.resetLe = now;
      }
      if (matiereAjoutee != null && titreAjoute != null) {
        final id = identifiantLeconSync(matiereAjoutee, titreAjoute);
        meta.suppressionsLocales.remove(id);
        meta.modifsLocales[id] = now;
      }
      await _ecrireMeta(meta);
      _programmerSynchro();
    });
    return _metaQueue;
  }

  Future<void> _enregistrerSuppression(String matiere, String titre) {
    _metaQueue = _metaQueue.then((_) async {
      final now = DateTime.now().toUtc().toIso8601String();
      final meta = await _lireMeta();
      final id = identifiantLeconSync(matiere, titre);
      meta.suppressionsLocales[id] = now;
      meta.modifsLocales.remove(id);
      await _ecrireMeta(meta);
      _programmerSynchro();
    });
    return _metaQueue;
  }

  void _programmerSynchro() {
    if (!estConfigure) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      unawaited(synchroniserMaintenant());
    });
  }

  Future<bool> synchroniserMaintenant() async {
    await initialiser();
    await _metaQueue;
    final cfg = _auth.config;
    if (cfg == null) return false;
    if (_enCours) {
      _relancer = true;
      return true;
    }
    _enCours = true;
    _etat = EtatSyncLabo.synchronisation;
    _erreur = null;
    notifyListeners();

    var succes = false;
    try {
      final client = LaboFirestoreClient(
        projectId: cfg.projectId,
        jetonValide: _auth.obtenirJetonValide,
        client: _httpClient,
      );
      final modifie = await _executerSynchro(client);
      if (modifie) {
        _revisionLocale++;
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final meta = await _lireMeta();
      meta.derniereSyncLe = now;
      await _ecrireMeta(meta);
      _derniereSyncLe = now;
      _etat = EtatSyncLabo.aJour;
      _erreur = null;
      succes = true;
    } on ErreurSyncLabo catch (e) {
      _erreur = e.message;
      _etat = e.horsLigne ? EtatSyncLabo.horsLigne : EtatSyncLabo.erreur;
    } catch (_) {
      _erreur = 'Erreur inattendue pendant la synchronisation.';
      _etat = EtatSyncLabo.erreur;
    } finally {
      _enCours = false;
      notifyListeners();
    }

    if (_relancer) {
      _relancer = false;
      return synchroniserMaintenant();
    }
    return succes;
  }

  Future<bool> _executerSynchro(LaboFirestoreClient client) async {
    final prefs = await SharedPreferences.getInstance();
    var meta = await _lireMeta(prefs);

    // 1. Synchronisation des leçons (`labo_lecons`).
    final localesCustom = _lireCustomLessons(prefs);
    final docsLecons = await client.listerCollection('labo_lecons');
    final distantes = <String, LeconSyncDistante>{};
    for (final e in docsLecons.entries) {
      final parsed = LeconSyncDistante.tryFromFirestoreFields(e.key, e.value);
      if (parsed != null) distantes[e.key] = parsed;
    }

    final titresBase = {
      for (final liste in InitialDatabase.data.values)
        for (final l in liste) l.titre,
    };

    final resLecons = fusionnerLecons(
      localesCustom: localesCustom,
      distantes: distantes,
      suppressionsLocales: meta.suppressionsLocales,
      titresBase: titresBase,
      modifsLocales: meta.modifsLocales,
    );

    for (final item in resLecons.aEnvoyer) {
      await client.ecrireDocument(
        'labo_lecons/${item.id}',
        item.toFirestoreFields(),
      );
      meta.modifsLocales.remove(item.id);
    }

    meta.suppressionsLocales = resLecons.suppressionsRestantes;
    if (resLecons.modifieLocalement) {
      await _ecrireCustomLessons(prefs, resLecons.localesFusionnees);
    }

    // 2. Synchronisation de la progression (`labo_progression/emile`).
    await MemoireService().charger();
    // Relire les métadonnées au cas où l'utilisateur aurait modifié entre-temps.
    final metaFraiche = await _lireMeta(prefs);
    metaFraiche.suppressionsLocales = meta.suppressionsLocales;
    metaFraiche.modifsLocales = meta.modifsLocales;
    meta = metaFraiche;

    final progLocale = _construireProgressionLocale(prefs, meta);
    final docProg = await client.lireDocument('labo_progression/emile');
    final progDistante = ProgressionSync.tryFromJsonString(
      docProg?['json'] as String?,
    );

    final resProg = fusionnerProgression(progLocale, progDistante);
    if (resProg.modifieLocalement) {
      await _appliquerProgressionLocale(prefs, resProg.fusionnee, meta);
    }
    if (resProg.doitEnvoyer) {
      final now = DateTime.now().toUtc().toIso8601String();
      await client.ecrireDocument('labo_progression/emile', {
        'json': resProg.fusionnee.toJsonString(),
        'modifieLe': now,
      });
    }
    await _ecrireMeta(meta, prefs);

    return resLecons.modifieLocalement || resProg.modifieLocalement;
  }

  Map<String, List<LessonModel>> _lireCustomLessons(SharedPreferences prefs) {
    final raw = prefs.getString('custom_lessons');
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final res = <String, List<LessonModel>>{};
      for (final e in decoded.entries) {
        if (e.value is! List) continue;
        res[e.key] = [
          for (final l in (e.value as List))
            LessonModel.fromJson(l as Map<String, dynamic>),
        ];
      }
      return res;
    } catch (_) {
      return {};
    }
  }

  Future<void> _ecrireCustomLessons(
    SharedPreferences prefs,
    Map<String, List<LessonModel>> base,
  ) async {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final e in base.entries) {
      if (e.value.isNotEmpty) {
        map[e.key] = [for (final l in e.value) l.toJson()];
      }
    }
    await prefs.setString('custom_lessons', jsonEncode(map));
  }

  ProgressionSync _construireProgressionLocale(
    SharedPreferences prefs,
    _MetaSync meta,
  ) {
    final etoiles = <String, List<bool>>{};
    final cartesDiamant = <String, String>{};
    final seanceVus = <String, List<String>>{};

    for (final cle in prefs.getKeys()) {
      if (cle.endsWith('_star_astuces')) {
        final titre = cle.substring(0, cle.length - '_star_astuces'.length);
        final arr = etoiles.putIfAbsent(titre, () => [false, false, false]);
        arr[0] = prefs.getBool(cle) ?? false;
      } else if (cle.endsWith('_star_train')) {
        final titre = cle.substring(0, cle.length - '_star_train'.length);
        final arr = etoiles.putIfAbsent(titre, () => [false, false, false]);
        arr[1] = prefs.getBool(cle) ?? false;
      } else if (cle.endsWith('_star_quiz')) {
        final titre = cle.substring(0, cle.length - '_star_quiz'.length);
        final arr = etoiles.putIfAbsent(titre, () => [false, false, false]);
        arr[2] = prefs.getBool(cle) ?? false;
      } else if (cle.startsWith('cartes_diamant_')) {
        final titre = cle.substring('cartes_diamant_'.length);
        final v = prefs.getString(cle);
        if (v != null) cartesDiamant[titre] = v;
      } else if (cle.startsWith('seance_vus_')) {
        final titre = cle.substring('seance_vus_'.length);
        final v = prefs.getStringList(cle);
        if (v != null) seanceVus[titre] = v;
      }
    }

    return ProgressionSync(
      diamants: prefs.getInt('emile_diamonds') ?? 0,
      diamantsModifieLe: meta.diamantsModifieLe,
      resetLe: meta.resetLe,
      derniereLeconImportee: prefs.getString('derniere_lecon_importee'),
      revisionDiamantsJour: prefs.getString('revision_diamants_jour'),
      etoiles: etoiles,
      cartesDiamant: cartesDiamant,
      seanceVus: seanceVus,
      memoireJson: MemoireService().memoire.toJsonString(),
      leconsBaseSupprimees:
          prefs.getStringList('deleted_initial_lessons') ?? const [],
      questionsMasquees:
          prefs.getStringList(QuestionsMasqueesService.kCle) ?? const [],
    );
  }

  Future<void> _appliquerProgressionLocale(
    SharedPreferences prefs,
    ProgressionSync p,
    _MetaSync meta,
  ) async {
    await prefs.setInt('emile_diamonds', p.diamants);
    if (p.derniereLeconImportee != null) {
      await prefs.setString(
        'derniere_lecon_importee',
        p.derniereLeconImportee!,
      );
    }
    if (p.revisionDiamantsJour != null) {
      await prefs.setString('revision_diamants_jour', p.revisionDiamantsJour!);
    }

    for (final cle in prefs.getKeys().toList()) {
      if (cle.endsWith('_star_astuces') ||
          cle.endsWith('_star_train') ||
          cle.endsWith('_star_quiz') ||
          cle.startsWith('cartes_diamant_') ||
          cle.startsWith('seance_vus_')) {
        await prefs.remove(cle);
      }
    }

    for (final e in p.etoiles.entries) {
      await prefs.setBool('${e.key}_star_astuces', e.value[0]);
      await prefs.setBool('${e.key}_star_train', e.value[1]);
      await prefs.setBool('${e.key}_star_quiz', e.value[2]);
    }
    for (final e in p.cartesDiamant.entries) {
      await prefs.setString('cartes_diamant_${e.key}', e.value);
    }
    for (final e in p.seanceVus.entries) {
      await prefs.setStringList('seance_vus_${e.key}', e.value);
    }

    await prefs.setString(MemoireService.kCle, p.memoireJson);
    await MemoireService().charger(forcer: true);

    if (p.leconsBaseSupprimees.isEmpty) {
      await prefs.remove('deleted_initial_lessons');
    } else {
      await prefs.setStringList(
        'deleted_initial_lessons',
        p.leconsBaseSupprimees,
      );
    }
    if (p.questionsMasquees.isEmpty) {
      await prefs.remove(QuestionsMasqueesService.kCle);
    } else {
      await prefs.setStringList(
        QuestionsMasqueesService.kCle,
        p.questionsMasquees,
      );
    }
    await QuestionsMasqueesService().charger(forcer: true);

    if (p.diamantsModifieLe.isNotEmpty) {
      meta.diamantsModifieLe = p.diamantsModifieLe;
    }
    if (p.resetLe != null) {
      meta.resetLe = p.resetLe;
    }
  }

  Future<_MetaSync> _lireMeta([SharedPreferences? p]) async {
    final prefs = p ?? await SharedPreferences.getInstance();
    return _MetaSync.lire(prefs.getString(kCleMetaSync));
  }

  Future<void> _ecrireMeta(_MetaSync meta, [SharedPreferences? p]) async {
    final prefs = p ?? await SharedPreferences.getInstance();
    await prefs.setString(kCleMetaSync, meta.toJsonString());
  }
}

class _MetaSync {
  String diamantsModifieLe;
  String? resetLe;
  String? derniereSyncLe;
  Map<String, String> suppressionsLocales;
  Map<String, String> modifsLocales;

  _MetaSync({
    this.diamantsModifieLe = '',
    this.resetLe,
    this.derniereSyncLe,
    Map<String, String>? suppressionsLocales,
    Map<String, String>? modifsLocales,
  }) : suppressionsLocales = suppressionsLocales ?? {},
       modifsLocales = modifsLocales ?? {};

  String toJsonString() => jsonEncode({
    'diamantsModifieLe': diamantsModifieLe,
    'resetLe': resetLe,
    'derniereSyncLe': derniereSyncLe,
    'suppressionsLocales': suppressionsLocales,
    'modifsLocales': modifsLocales,
  });

  static _MetaSync lire(String? raw) {
    if (raw == null || raw.isEmpty) return _MetaSync();
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final sups = <String, String>{};
      final rawSups = m['suppressionsLocales'];
      if (rawSups is Map) {
        for (final e in rawSups.entries) {
          if (e.key is String && e.value is String) {
            sups[e.key as String] = e.value as String;
          }
        }
      }
      final mods = <String, String>{};
      final rawMods = m['modifsLocales'];
      if (rawMods is Map) {
        for (final e in rawMods.entries) {
          if (e.key is String && e.value is String) {
            mods[e.key as String] = e.value as String;
          }
        }
      }
      return _MetaSync(
        diamantsModifieLe: (m['diamantsModifieLe'] as String?) ?? '',
        resetLe: m['resetLe'] as String?,
        derniereSyncLe: m['derniereSyncLe'] as String?,
        suppressionsLocales: sups,
        modifsLocales: mods,
      );
    } catch (_) {
      return _MetaSync();
    }
  }
}

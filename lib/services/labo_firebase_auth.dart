import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Erreur lisible en français lors de la connexion ou synchronisation Firebase.
class ErreurSyncLabo implements Exception {
  final String message;
  final bool horsLigne;

  const ErreurSyncLabo(this.message, {this.horsLigne = false});

  @override
  String toString() => message;
}

/// Session persistée pour la synchronisation du Labo (jamais le mot de passe).
class ConfigFirebaseLabo {
  final String projectId;
  final String webApiKey;
  final String email;
  final String refreshToken;
  final String uid;

  const ConfigFirebaseLabo({
    required this.projectId,
    required this.webApiKey,
    required this.email,
    required this.refreshToken,
    required this.uid,
  });

  Map<String, String> toJson() => {
    'projectId': projectId,
    'webApiKey': webApiKey,
    'email': email,
    'refreshToken': refreshToken,
    'uid': uid,
  };

  static ConfigFirebaseLabo? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      final projectId = json['projectId'];
      final webApiKey = json['webApiKey'];
      final email = json['email'];
      final refreshToken = json['refreshToken'];
      final uid = json['uid'];
      if (projectId is! String ||
          webApiKey is! String ||
          email is! String ||
          refreshToken is! String ||
          uid is! String) {
        return null;
      }
      if (projectId.isEmpty ||
          webApiKey.isEmpty ||
          refreshToken.isEmpty ||
          uid.isEmpty) {
        return null;
      }
      return ConfigFirebaseLabo(
        projectId: projectId,
        webApiKey: webApiKey,
        email: email,
        refreshToken: refreshToken,
        uid: uid,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Accepte soit une clé API Web brute (`AIza...`), soit le JSON complet d'une
/// configuration Firebase (`webApiKey` ou `apiKey`, et `projectId`).
({String projectId, String webApiKey}) extraireCleOuJsonFirebase(
  String saisie, {
  String projectIdDefaut = 'reviser-bdd1a',
}) {
  final defaut = projectIdDefaut.trim().isEmpty
      ? 'reviser-bdd1a'
      : projectIdDefaut.trim();
  final propre = saisie.trim();
  if (propre.startsWith('{')) {
    try {
      final json = jsonDecode(propre);
      if (json is Map<String, dynamic>) {
        final rawCle = json['webApiKey'] ?? json['apiKey'];
        final rawProj = json['projectId'];
        final cle = rawCle is String ? rawCle.trim() : '';
        final proj = (rawProj is String && rawProj.trim().isNotEmpty)
            ? rawProj.trim()
            : defaut;
        return (projectId: proj, webApiKey: cle);
      }
    } catch (_) {
      return (projectId: defaut, webApiKey: '');
    }
    return (projectId: defaut, webApiKey: '');
  }
  return (projectId: defaut, webApiKey: propre);
}

/// Authentification Firebase REST (e-mail + mot de passe) en Dart pur.
class LaboFirebaseAuth {
  LaboFirebaseAuth({
    required Future<String?> Function() lireStockage,
    required Future<void> Function(String?) ecrireStockage,
    http.Client? client,
    DateTime Function()? horloge,
    this.timeout = const Duration(seconds: 25),
  }) : _lireStockage = lireStockage,
       _ecrireStockage = ecrireStockage,
       _client = client ?? http.Client(),
       _horloge = horloge ?? DateTime.now;

  final Future<String?> Function() _lireStockage;
  final Future<void> Function(String?) _ecrireStockage;
  final http.Client _client;
  final DateTime Function() _horloge;
  final Duration timeout;

  ConfigFirebaseLabo? _config;
  String? _idToken;
  DateTime? _expiration;

  ConfigFirebaseLabo? get config => _config;
  bool get estConnecte => _config != null;

  Future<ConfigFirebaseLabo?> charger() async {
    try {
      _config = ConfigFirebaseLabo.tryParse(await _lireStockage());
    } catch (_) {
      _config = null;
    }
    return _config;
  }

  Future<ConfigFirebaseLabo> connecter({
    required String projectId,
    required String webApiKey,
    required String email,
    required String motDePasse,
  }) async {
    final proj = projectId.trim();
    final cle = webApiKey.trim();
    final mail = email.trim();
    if (proj.isEmpty || cle.isEmpty) {
      throw const ErreurSyncLabo('Renseigne la clé API Web Firebase.');
    }
    if (mail.isEmpty || motDePasse.isEmpty) {
      throw const ErreurSyncLabo('Renseigne l’e-mail et le mot de passe.');
    }

    final uri = Uri.https(
      'identitytoolkit.googleapis.com',
      '/v1/accounts:signInWithPassword',
      {'key': cle},
    );
    final data = await _postJson(
      uri,
      jsonEncode({
        'email': mail,
        'password': motDePasse,
        'returnSecureToken': true,
      }),
      {'Content-Type': 'application/json'},
    );

    final uid = data['localId'];
    final idToken = data['idToken'];
    final refreshToken = data['refreshToken'];
    if (uid is! String || idToken is! String || refreshToken is! String) {
      throw const ErreurSyncLabo('Réponse de Firebase inexploitable.');
    }

    final nouvelle = ConfigFirebaseLabo(
      projectId: proj,
      webApiKey: cle,
      email: (data['email'] as String?) ?? mail,
      refreshToken: refreshToken,
      uid: uid,
    );
    _config = nouvelle;
    _memoriserJeton(idToken, data['expiresIn']);
    await _ecrireStockage(jsonEncode(nouvelle.toJson()));
    return nouvelle;
  }

  Future<String> obtenirJetonValide() async {
    final cfg = _config;
    if (cfg == null) {
      throw const ErreurSyncLabo('Synchronisation Firebase non configurée.');
    }
    final tok = _idToken;
    final exp = _expiration;
    if (tok != null && exp != null && _horloge().isBefore(exp)) {
      return tok;
    }

    final uri = Uri.https('securetoken.googleapis.com', '/v1/token', {
      'key': cfg.webApiKey,
    });
    final data = await _postJson(
      uri,
      {'grant_type': 'refresh_token', 'refresh_token': cfg.refreshToken},
      null,
    );

    final frais = data['id_token'];
    if (frais is! String) {
      throw const ErreurSyncLabo('Réponse de Firebase inexploitable.');
    }
    _memoriserJeton(frais, data['expires_in']);
    final nouveauRefresh = data['refresh_token'];
    if (nouveauRefresh is String && nouveauRefresh != cfg.refreshToken) {
      _config = ConfigFirebaseLabo(
        projectId: cfg.projectId,
        webApiKey: cfg.webApiKey,
        email: cfg.email,
        refreshToken: nouveauRefresh,
        uid: cfg.uid,
      );
      await _ecrireStockage(jsonEncode(_config!.toJson()));
    }
    return frais;
  }

  Future<void> deconnecter() async {
    _config = null;
    _idToken = null;
    _expiration = null;
    await _ecrireStockage(null);
  }

  void _memoriserJeton(String token, Object? expiresIn) {
    _idToken = token;
    final sec = int.tryParse('$expiresIn') ?? 3600;
    final marge = (sec - 60).clamp(30, 86400);
    _expiration = _horloge().add(Duration(seconds: marge));
  }

  Future<Map<String, Object?>> _postJson(
    Uri uri,
    Object body,
    Map<String, String>? headers,
  ) async {
    final http.Response response;
    try {
      response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(timeout);
    } on TimeoutException {
      throw const ErreurSyncLabo(
        "Firebase n'a pas répondu à temps.",
        horsLigne: true,
      );
    } catch (_) {
      throw const ErreurSyncLabo('Pas de réseau.', horsLigne: true);
    }

    final Map<String, Object?> data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;
    } catch (_) {
      throw ErreurSyncLabo(
        'Réponse de Firebase illisible (code ${response.statusCode}).',
      );
    }

    if (response.statusCode != 200) {
      final err = data['error'];
      final codeMsg = err is Map ? '${err['message'] ?? ''}' : '';
      throw ErreurSyncLabo(_traduireErreurAuth(codeMsg, response.statusCode));
    }
    return data;
  }

  static String _traduireErreurAuth(String codeMsg, int statusCode) {
    final m = codeMsg.toUpperCase();
    if (m.contains('INVALID_LOGIN_CREDENTIALS') ||
        m.contains('INVALID_PASSWORD') ||
        m.contains('EMAIL_NOT_FOUND') ||
        m.contains('USER_NOT_FOUND')) {
      return 'E-mail ou mot de passe incorrect.';
    }
    if (m.contains('INVALID_EMAIL')) {
      return 'Adresse e-mail invalide.';
    }
    if (m.contains('USER_DISABLED')) {
      return 'Ce compte a été désactivé dans Firebase.';
    }
    if (m.contains('API_KEY')) {
      return 'Clé API Web Firebase invalide.';
    }
    if (m.contains('TOO_MANY_ATTEMPTS')) {
      return 'Trop d’essais : réessaie dans quelques minutes.';
    }
    if (m.contains('TOKEN_EXPIRED') || m.contains('INVALID_REFRESH_TOKEN')) {
      return 'Session expirée : reconnecte le compte dans l’Espace Parent.';
    }
    return 'Connexion Firebase refusée (code $statusCode).';
  }
}

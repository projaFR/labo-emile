import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

export 'labo_sync_plateforme.dart'
    show chargerConfigOAuthDepuisReviser, obtenirIdTokenGoogleLoopback;

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
  final String? desktopClientId;
  final String? desktopClientSecret;

  const ConfigFirebaseLabo({
    required this.projectId,
    required this.webApiKey,
    required this.email,
    required this.refreshToken,
    required this.uid,
    this.desktopClientId,
    this.desktopClientSecret,
  });

  Map<String, String> toJson() => {
    'projectId': projectId,
    'webApiKey': webApiKey,
    'email': email,
    'refreshToken': refreshToken,
    'uid': uid,
    if (desktopClientId != null && desktopClientId!.isNotEmpty)
      'desktopClientId': desktopClientId!,
    if (desktopClientSecret != null && desktopClientSecret!.isNotEmpty)
      'desktopClientSecret': desktopClientSecret!,
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
      final rawCid = json['desktopClientId'];
      final rawSec = json['desktopClientSecret'];
      return ConfigFirebaseLabo(
        projectId: projectId,
        webApiKey: webApiKey,
        email: email,
        refreshToken: refreshToken,
        uid: uid,
        desktopClientId:
            (rawCid is String && rawCid.trim().isNotEmpty) ? rawCid.trim() : null,
        desktopClientSecret:
            (rawSec is String && rawSec.trim().isNotEmpty) ? rawSec.trim() : null,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Identifiants OAuth Google lus à l'exécution (sur PC depuis Réviser) ou collés.
class ConfigOAuthGoogleLabo {
  final String projectId;
  final String webApiKey;
  final String desktopClientId;
  final String desktopClientSecret;

  const ConfigOAuthGoogleLabo({
    required this.projectId,
    required this.webApiKey,
    required this.desktopClientId,
    required this.desktopClientSecret,
  });

  Map<String, String> toJson() => {
    'projectId': projectId,
    'webApiKey': webApiKey,
    'desktopClientId': desktopClientId,
    'desktopClientSecret': desktopClientSecret,
  };

  static ConfigOAuthGoogleLabo? tryParse(
    String? raw, {
    String projectIdDefaut = 'reviser-bdd1a',
  }) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) return null;
      final rawProj = json['projectId'];
      final rawKey = json['webApiKey'] ?? json['apiKey'];
      final rawId = json['desktopClientId'];
      final rawSecret = json['desktopClientSecret'];
      if (rawKey is! String || rawId is! String || rawSecret is! String) {
        return null;
      }
      final projectId =
          (rawProj is String && rawProj.trim().isNotEmpty)
              ? rawProj.trim()
              : projectIdDefaut;
      final webApiKey = rawKey.trim();
      final desktopClientId = rawId.trim();
      final desktopClientSecret = rawSecret.trim();
      final ok = [
        projectId,
        webApiKey,
        desktopClientId,
        desktopClientSecret,
      ].every((v) => v.isNotEmpty && !v.startsWith('COLLE_ICI'));
      if (!ok) return null;
      return ConfigOAuthGoogleLabo(
        projectId: projectId,
        webApiKey: webApiKey,
        desktopClientId: desktopClientId,
        desktopClientSecret: desktopClientSecret,
      );
    } catch (_) {
      return null;
    }
  }
}

const List<int> _sha256K = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

int _rotr32(int x, int n) {
  final u = x & 0xffffffff;
  return ((u >> n) | (u << (32 - n))) & 0xffffffff;
}

/// Empreinte SHA-256 en Dart pur (FIPS 180-4) pour le challenge PKCE `S256`.
List<int> sha256Bytes(List<int> message) {
  final bitLen = message.length * 8;
  final paddedLen = ((message.length + 9 + 63) ~/ 64) * 64;
  final padded = Uint8List(paddedLen)..setRange(0, message.length, message);
  padded[message.length] = 0x80;
  final bd = ByteData.sublistView(padded);
  bd.setUint32(paddedLen - 8, (bitLen ~/ 0x100000000) & 0xffffffff, Endian.big);
  bd.setUint32(paddedLen - 4, bitLen & 0xffffffff, Endian.big);

  final h = Uint32List.fromList([
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ]);
  final w = Uint32List(64);

  for (var offset = 0; offset < paddedLen; offset += 64) {
    for (var i = 0; i < 16; i++) {
      w[i] = bd.getUint32(offset + i * 4, Endian.big);
    }
    for (var i = 16; i < 64; i++) {
      final v15 = w[i - 15];
      final v2 = w[i - 2];
      final s0 = _rotr32(v15, 7) ^ _rotr32(v15, 18) ^ (v15 >> 3);
      final s1 = _rotr32(v2, 17) ^ _rotr32(v2, 19) ^ (v2 >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }

    var a = h[0], b = h[1], c = h[2], d = h[3];
    var e = h[4], f = h[5], g = h[6], hh = h[7];

    for (var i = 0; i < 64; i++) {
      final s1 = _rotr32(e, 6) ^ _rotr32(e, 11) ^ _rotr32(e, 25);
      final ch = (e & f) ^ ((~e) & g);
      final temp1 = (hh + s1 + ch + _sha256K[i] + w[i]) & 0xffffffff;
      final s0 = _rotr32(a, 2) ^ _rotr32(a, 13) ^ _rotr32(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xffffffff;

      hh = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }

    h[0] = (h[0] + a) & 0xffffffff;
    h[1] = (h[1] + b) & 0xffffffff;
    h[2] = (h[2] + c) & 0xffffffff;
    h[3] = (h[3] + d) & 0xffffffff;
    h[4] = (h[4] + e) & 0xffffffff;
    h[5] = (h[5] + f) & 0xffffffff;
    h[6] = (h[6] + g) & 0xffffffff;
    h[7] = (h[7] + hh) & 0xffffffff;
  }

  final out = Uint8List(32);
  final outBd = ByteData.sublistView(out);
  for (var i = 0; i < 8; i++) {
    outBd.setUint32(i * 4, h[i], Endian.big);
  }
  return out;
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

    return _finaliserConnexion(
      data: data,
      projectId: proj,
      webApiKey: cle,
      emailRepli: mail,
    );
  }

  Future<ConfigFirebaseLabo> connecterAvecGoogleIdToken({
    required String projectId,
    required String webApiKey,
    required String googleIdToken,
    String? desktopClientId,
    String? desktopClientSecret,
  }) async {
    final proj = projectId.trim();
    final cle = webApiKey.trim();
    final tok = googleIdToken.trim();
    if (proj.isEmpty || cle.isEmpty || tok.isEmpty) {
      throw const ErreurSyncLabo('Paramètres Google Firebase incomplets.');
    }

    final uri = Uri.https(
      'identitytoolkit.googleapis.com',
      '/v1/accounts:signInWithIdp',
      {'key': cle},
    );
    final data = await _postJson(
      uri,
      jsonEncode({
        'postBody': 'id_token=$tok&providerId=google.com',
        'requestUri': 'http://localhost',
        'returnSecureToken': true,
        'returnIdpCredential': false,
      }),
      {'Content-Type': 'application/json'},
    );

    return _finaliserConnexion(
      data: data,
      projectId: proj,
      webApiKey: cle,
      desktopClientId: desktopClientId,
      desktopClientSecret: desktopClientSecret,
    );
  }

  Future<ConfigFirebaseLabo> _finaliserConnexion({
    required Map<String, Object?> data,
    required String projectId,
    required String webApiKey,
    String emailRepli = '',
    String? desktopClientId,
    String? desktopClientSecret,
  }) async {
    final uid = data['localId'];
    final idToken = data['idToken'];
    final refreshToken = data['refreshToken'];
    if (uid is! String || idToken is! String || refreshToken is! String) {
      throw const ErreurSyncLabo('Réponse de Firebase inexploitable.');
    }

    final nouvelle = ConfigFirebaseLabo(
      projectId: projectId,
      webApiKey: webApiKey,
      email: (data['email'] as String?) ?? emailRepli,
      refreshToken: refreshToken,
      uid: uid,
      desktopClientId: desktopClientId,
      desktopClientSecret: desktopClientSecret,
    );
    _config = nouvelle;
    _memoriserJeton(idToken, data['expiresIn']);
    await _ecrireStockage(jsonEncode(nouvelle.toJson()));
    return nouvelle;
  }

  /// Importe directement une session déjà authentifiée (ex. reçue via USB).
  Future<void> importerSession(ConfigFirebaseLabo session) async {
    _config = session;
    _idToken = null;
    _expiration = null;
    await _ecrireStockage(jsonEncode(session.toJson()));
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
        desktopClientId: cfg.desktopClientId,
        desktopClientSecret: cfg.desktopClientSecret,
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
    if (m.contains('OPERATION_NOT_ALLOWED')) {
      return 'Ce mode de connexion est désactivé dans Firebase Authentication.';
    }
    if (m.contains('INVALID_IDP_RESPONSE')) {
      return 'Jeton Google refusé par Firebase.';
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

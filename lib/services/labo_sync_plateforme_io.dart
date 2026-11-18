import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'labo_firebase_auth.dart';

/// Sur Windows, lit `Reviser\assets\firebase_config.json` au moment de
/// l'exécution (ce secret reste uniquement chez Réviser, jamais dans ce dépôt).
Future<ConfigOAuthGoogleLabo?> chargerConfigOAuthDepuisReviser() async {
  if (!Platform.isWindows) return null;
  final sep = Platform.pathSeparator;
  final candidats = <String>[
    r'C:\Users\proja\Projets\Reviser\assets\firebase_config.json',
    if ((Platform.environment['USERPROFILE'] ?? '').isNotEmpty)
      '${Platform.environment['USERPROFILE']}'
          r'\Projets\Reviser\assets\firebase_config.json',
    r'..\Reviser\assets\firebase_config.json',
  ];

  try {
    var dir = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 8; i++) {
      candidats.add(
        '${dir.path}${sep}Reviser${sep}assets${sep}firebase_config.json',
      );
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (_) {}

  final vus = <String>{};
  for (final chemin in candidats) {
    if (!vus.add(chemin)) continue;
    try {
      final f = File(chemin);
      if (!f.existsSync()) continue;
      final cfg = ConfigOAuthGoogleLabo.tryParse(await f.readAsString());
      if (cfg != null) return cfg;
    } catch (_) {}
  }
  return null;
}

String _randomBase64Url() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

/// Obtient un `id_token` Google en ouvrant le navigateur avec retour loopback.
Future<String> obtenirIdTokenGoogleLoopback({
  required ConfigOAuthGoogleLabo oauthConfig,
  required Future<bool> Function(Uri url) ouvrirNavigateur,
  http.Client? client,
  Duration timeoutNavigateur = const Duration(minutes: 3),
}) async {
  final verifier = _randomBase64Url();
  final state = _randomBase64Url();
  final challenge =
      base64UrlEncode(sha256Bytes(ascii.encode(verifier))).replaceAll('=', '');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final redirectUri = 'http://127.0.0.1:${server.port}';
  final httpClient = client ?? http.Client();
  final doitFermerClient = client == null;

  try {
    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': oauthConfig.desktopClientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid email',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
      'prompt': 'select_account',
    });

    final ouvert = await ouvrirNavigateur(authUri);
    if (!ouvert) {
      throw const ErreurSyncLabo(
        "Impossible d'ouvrir le navigateur pour la connexion Google.",
      );
    }

    final code = await _attendreCodeLoopback(server, state).timeout(
      timeoutNavigateur,
      onTimeout: () =>
          throw const ErreurSyncLabo('Connexion Google annulée : délai dépassé.'),
    );

    final http.Response response;
    try {
      response = await httpClient
          .post(
            Uri.https('oauth2.googleapis.com', '/token'),
            body: {
              'client_id': oauthConfig.desktopClientId,
              'client_secret': oauthConfig.desktopClientSecret,
              'code': code,
              'code_verifier': verifier,
              'grant_type': 'authorization_code',
              'redirect_uri': redirectUri,
            },
          )
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const ErreurSyncLabo(
        "Google n'a pas répondu à temps.",
        horsLigne: true,
      );
    } catch (_) {
      throw const ErreurSyncLabo(
        'Pas de réseau : la connexion Google a échoué.',
        horsLigne: true,
      );
    }

    if (response.statusCode != 200) {
      throw ErreurSyncLabo(
        'Google a refusé la connexion (code ${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final idToken =
        decoded is Map<String, Object?> ? decoded['id_token'] : null;
    if (idToken is! String || idToken.isEmpty) {
      throw const ErreurSyncLabo("Google n'a pas renvoyé de jeton.");
    }
    return idToken;
  } finally {
    await server.close(force: true);
    if (doitFermerClient) httpClient.close();
  }
}

Future<String> _attendreCodeLoopback(HttpServer server, String state) async {
  await for (final request in server) {
    final params = request.uri.queryParameters;
    if (!params.containsKey('code') && !params.containsKey('error')) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }

    final code = params['code'];
    final valid = params['state'] == state && code != null && code.isNotEmpty;
    final messageHtml = valid
        ? 'Connexion réussie ! Tu peux fermer cet onglet et revenir au Labo d’Émile.'
        : 'La connexion a échoué. Tu peux fermer cet onglet.';
    request.response
      ..statusCode = valid ? HttpStatus.ok : HttpStatus.badRequest
      ..headers.contentType = ContentType('text', 'html', charset: 'utf-8')
      ..write(
        '<!doctype html><meta charset="utf-8"><title>Labo d’Émile</title>'
        '<p style="font:18px sans-serif;margin:3em;text-align:center">'
        '$messageHtml</p>',
      );
    await request.response.close();

    if (!valid) {
      throw ErreurSyncLabo(
        params['error'] == 'access_denied'
            ? 'Connexion Google annulée.'
            : 'Google a refusé la connexion.',
      );
    }
    return code;
  }
  throw const ErreurSyncLabo('Connexion Google interrompue.');
}

Future<bool> ouvrirNavigateurOAuth(
  Uri url,
  Future<bool> Function(Uri url) ouvrirAndroid,
) async {
  if (Platform.isWindows) {
    try {
      final res = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'Start-Process $env:LABO_AUTH_URL',
        ],
        environment: {'LABO_AUTH_URL': url.toString()},
      );
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
  if (Platform.isAndroid) {
    return ouvrirAndroid(url);
  }
  return false;
}

Future<({bool ok, String message})> envoyerSessionUsbAdb(String b64) async {
  var adbExe = 'adb';
  final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
  if (localAppData.isNotEmpty) {
    final candidat = '$localAppData\\Android\\Sdk\\platform-tools\\adb.exe';
    if (File(candidat).existsSync()) {
      adbExe = candidat;
    }
  }

  try {
    await Process.run(adbExe, ['start-server']);
    await Future<void>.delayed(const Duration(seconds: 4));
    final res = await Process.run(adbExe, [
      'shell',
      'am',
      'start',
      '-n',
      'fr.thibaut.laboemile/.MainActivity',
      '--es',
      'firebase_session_b64',
      b64,
    ]);
    final sortie = '${res.stdout}\n${res.stderr}';
    if (res.exitCode == 0 && !sortie.contains('Error:')) {
      return (
        ok: true,
        message:
            'Compte Google envoyé au téléphone ! Le Labo d’Émile sur le téléphone est maintenant connecté.',
      );
    }
    final bas = sortie.toLowerCase();
    if (bas.contains('unauthorized') || bas.contains('authorizing')) {
      return (
        ok: false,
        message:
            'Téléphone non autorisé : déverrouille-le et accepte le débogage USB.',
      );
    }
    if (bas.contains('no devices')) {
      return (ok: false, message: 'Aucun téléphone détecté en USB.');
    }
    return (
      ok: false,
      message: 'Transfert USB impossible (vérifie le câble et le débogage USB).',
    );
  } catch (_) {
    return (
      ok: false,
      message: 'Outil ADB introuvable ou transfert USB impossible.',
    );
  }
}

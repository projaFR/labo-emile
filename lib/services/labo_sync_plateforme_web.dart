import 'package:http/http.dart' as http;

import 'labo_firebase_auth.dart';

/// Sur le Web / iPad, aucun fichier local du PC n'est accessible.
Future<ConfigOAuthGoogleLabo?> chargerConfigOAuthDepuisReviser() async => null;

/// Non disponible sur le Web (utilise le code de connexion copié depuis le PC).
Future<String> obtenirIdTokenGoogleLoopback({
  required ConfigOAuthGoogleLabo oauthConfig,
  required Future<bool> Function(Uri url) ouvrirNavigateur,
  http.Client? client,
  Duration timeoutNavigateur = const Duration(minutes: 3),
}) async {
  throw const ErreurSyncLabo(
    'Sur iPad / navigateur, utilise le code de connexion copié depuis le PC.',
  );
}

Future<bool> ouvrirNavigateurOAuth(
  Uri url,
  Future<bool> Function(Uri url) ouvrirAndroid,
) async => false;

Future<({bool ok, String message})> envoyerSessionUsbAdb(String b64) async => (
  ok: false,
  message: 'Transfert USB disponible uniquement depuis le PC.',
);

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'labo_firebase_auth.dart';

/// Encode une valeur Dart au format de l'API REST de Firestore.
Map<String, Object?> encodeValeurFirestore(Object? value) => switch (value) {
  null => {'nullValue': null},
  final bool v => {'booleanValue': v},
  final int v => {'integerValue': '$v'},
  final double v => {'doubleValue': v},
  final String v => {'stringValue': v},
  _ => throw ArgumentError('Type non pris en charge : ${value.runtimeType}'),
};

Object? decodeValeurFirestore(Map<String, Object?> value) {
  if (value.containsKey('integerValue')) {
    return int.parse('${value['integerValue']}');
  }
  if (value.containsKey('stringValue')) return value['stringValue'];
  if (value.containsKey('booleanValue')) return value['booleanValue'];
  if (value.containsKey('doubleValue')) return value['doubleValue'];
  return null;
}

Map<String, Object?> decodeChampsFirestore(Map<String, Object?> document) {
  final fields = document['fields'] as Map<String, Object?>? ?? const {};
  return fields.map(
    (key, value) => MapEntry(key, decodeValeurFirestore(value as Map<String, Object?>)),
  );
}

/// Accès à Firestore via REST en Dart pur (compatible Android, Windows et Web).
class LaboFirestoreClient {
  LaboFirestoreClient({
    required this.projectId,
    required this.jetonValide,
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
  }) : _client = client ?? http.Client();

  final String projectId;
  final Future<String> Function() jetonValide;
  final http.Client _client;
  final Duration timeout;

  String get _base =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  /// Lit un document Firestore ; renvoie `null` s'il n'existe pas (404).
  Future<Map<String, Object?>?> lireDocument(String chemin) async {
    final response = await _envoyer(
      (headers) => _client.get(Uri.parse('$_base/$chemin'), headers: headers),
    );
    if (response.statusCode == 404) return null;
    _verifier(response);
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;
    return decodeChampsFirestore(data);
  }

  /// Liste tous les documents d'une collection (`id -> champs`).
  Future<Map<String, Map<String, Object?>>> listerCollection(
    String collection,
  ) async {
    final documents = <String, Map<String, Object?>>{};
    String? pageToken;
    do {
      final uri = Uri.parse('$_base/$collection').replace(
        queryParameters: {
          'pageSize': '200',
          'pageToken': ?pageToken,
        },
      );
      final response = await _envoyer(
        (headers) => _client.get(uri, headers: headers),
      );
      _verifier(response);
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;
      for (final doc in (data['documents'] as List? ?? const [])) {
        final map = doc as Map<String, Object?>;
        final id = (map['name'] as String).split('/').last;
        documents[id] = decodeChampsFirestore(map);
      }
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null);
    return documents;
  }

  /// Crée ou remplace un document Firestore (`PATCH`).
  Future<void> ecrireDocument(
    String chemin,
    Map<String, Object?> champs,
  ) async {
    final body = jsonEncode({
      'fields': champs.map((k, v) => MapEntry(k, encodeValeurFirestore(v))),
    });
    final response = await _envoyer(
      (headers) => _client.patch(
        Uri.parse('$_base/$chemin'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: body,
      ),
    );
    _verifier(response);
  }

  Future<http.Response> _envoyer(
    Future<http.Response> Function(Map<String, String> headers) requete,
  ) async {
    final token = await jetonValide();
    try {
      return await requete({'Authorization': 'Bearer $token'}).timeout(timeout);
    } on TimeoutException {
      throw const ErreurSyncLabo(
        "Firebase n'a pas répondu à temps.",
        horsLigne: true,
      );
    } catch (_) {
      throw const ErreurSyncLabo('Pas de réseau.', horsLigne: true);
    }
  }

  void _verifier(http.Response response) {
    if (response.statusCode == 200) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ErreurSyncLabo(
        'Firebase refuse l’accès : vérifie les règles Firestore ou reconnecte le compte.',
      );
    }
    throw ErreurSyncLabo(
      'Firebase a répondu avec une erreur (code ${response.statusCode}).',
    );
  }
}

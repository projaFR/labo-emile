import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/logic/lecon_json_logic.dart';
import 'package:myapp/services/gemini_key_store.dart';
import 'package:myapp/services/gemini_lecon_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jsonValide({String succes = '🦉 Dompteur de Hiboux'}) => jsonEncode({
  'matiere': 'Français',
  'titre': 'Le pluriel des noms en -ou',
  'succes': succes,
  'astuces': [
    {'question': 'Règle générale ?', 'reponse': 'Les noms en -ou prennent -s.'},
  ],
  'exercices': [
    {
      'question': 'Un hibou -> des [?]',
      'consigne': 'Choisis la bonne réponse :',
      'options': ['hiboux', 'bijoux', 'cailloux', 'genoux'],
      'reponseAttendue': 'hiboux',
      'astuceErreur': 'Cherche celui qui correspond à un oiseau de nuit.',
    },
    {
      'question': '10 + [?] = [?]',
      'consigne': 'Complète :',
      'reponsesMultiples': ['5', '15'],
      'astuceErreur': 'Ajoute 5 à 10.',
    },
  ],
  'quiz': [
    {
      'question': 'Quel mot prend un X au pluriel ?',
      'options': ['clou', 'trou', 'hibou', 'fou'],
      'indexCorrect': 2,
    },
  ],
});

void main() {
  group('lecon_json_logic', () {
    test('nettoie les balises markdown et parse succes', () {
      final brut = 'Voici :\n```json\n${_jsonValide()}\n```\nBon courage !';
      final res = analyserJsonLecon(brut);
      expect(res.matiere, 'Français');
      expect(res.lecon.titre, 'Le pluriel des noms en -ou');
      expect(res.lecon.succes, '🦉 Dompteur de Hiboux');
      expect(res.lecon.exercices.length, 2);
      expect(res.lecon.quiz.length, 1);
    });

    test('rejette titre absent, trous invalides et quiz invalide', () {
      expect(
        () => analyserJsonLecon('{"titre": " "}'),
        throwsFormatException,
      );
      expect(
        () => analyserJsonLecon(
          jsonEncode({
            'titre': 'Maths',
            'exercices': [
              {'question': '[?] + [?] = 10'},
            ],
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => analyserJsonLecon(
          jsonEncode({
            'titre': 'Maths',
            'quiz': [
              {
                'question': 'Q ?',
                'options': ['A', 'B'],
                'indexCorrect': 5,
              },
            ],
          }),
        ),
        throwsFormatException,
      );
    });
  });

  group('gemini_key_store', () {
    test('lit, enregistre, efface et masque la clé', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await lireCleGemini(), isNull);
      expect(masquerCleGemini(null), 'Aucune clé configurée');

      await enregistrerCleGemini('  AIzaTestKey9876  ');
      expect(await lireCleGemini(), 'AIzaTestKey9876');
      expect(masquerCleGemini('AIzaTestKey9876'), 'Clé configurée (••••9876)');

      await enregistrerCleGemini('   ');
      expect(await lireCleGemini(), isNull);
    });
  });

  group('gemini_lecon_service', () {
    final photo = PhotoLecon(
      octets: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
      mimeType: 'image/jpeg',
      nom: 'cahier.jpg',
    );

    test('succès au 1er essai', () async {
      var appels = 0;
      final client = MockClient((req) async {
        appels++;
        expect(req.headers['x-goog-api-key'], 'AIza123');
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': _jsonValide()},
                  ],
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final res = await genererLeconDepuisPhotos(
        apiKey: 'AIza123',
        photos: [photo],
        client: client,
      );
      expect(appels, 1);
      expect(res.lecon.titre, 'Le pluriel des noms en -ou');
      expect(res.lecon.succes, '🦉 Dompteur de Hiboux');
    });

    test('corrige automatiquement au 2e essai après JSON invalide', () async {
      var appels = 0;
      final client = MockClient((req) async {
        appels++;
        final corps = appels == 1
            ? '{"titre": "Invalide", "exercices": [{"question": "[?] + [?] = 4"}]}'
            : _jsonValide();
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': corps},
                  ],
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final res = await genererLeconDepuisPhotos(
        apiKey: 'AIza123',
        photos: [photo],
        client: client,
      );
      expect(appels, 2);
      expect(res.lecon.titre, 'Le pluriel des noms en -ou');
    });

    test('gère les erreurs 401/403 et 429 en français', () async {
      final client403 = MockClient(
        (_) async => http.Response('{"error": {}}', 403),
      );
      await expectLater(
        () => genererLeconDepuisPhotos(
          apiKey: 'mauvaise',
          photos: [photo],
          client: client403,
        ),
        throwsA(
          isA<ErreurGeminiLecon>().having(
            (e) => e.message,
            'message',
            contains('Clé Gemini refusée'),
          ),
        ),
      );

      final client429 = MockClient(
        (_) async => http.Response('{"error": {}}', 429),
      );
      await expectLater(
        () => genererLeconDepuisPhotos(
          apiKey: 'AIza123',
          photos: [photo],
          client: client429,
        ),
        throwsA(
          isA<ErreurGeminiLecon>().having(
            (e) => e.message,
            'message',
            contains('Limite gratuite Gemini atteinte'),
          ),
        ),
      );
    });
  });
}

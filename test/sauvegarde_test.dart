import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/data/database.dart';
import 'package:myapp/logic/memoire.dart';
import 'package:myapp/logic/sauvegarde.dart';
import 'package:myapp/models/lesson_model.dart';
import 'package:myapp/services/gemini_key_store.dart';
import 'package:myapp/services/labo_sync_service.dart';

Map<String, Object> _exemple() {
  final l = InitialDatabase.data.values.first.first;
  return {
    'emile_diamonds': 123,
    'custom_lessons': jsonEncode({
      'Maths': [l.toJson()],
    }),
    'memoire_v1': Memoire().toJsonString(),
    'reglage_sons': false,
    'reglage_vibrations': true,
    'reglage_chrono_secondes': 15,
    'derniere_lecon_importee': 'Ma leçon',
    'revision_diamants_jour': '2026-11-16',
    'Ma leçon_star_astuces': true,
    'Ma leçon_star_quiz': false,
    'seance_vus_Ma leçon': ['a', 'b'],
    'cartes_diamant_Ma leçon': '2026-11-16',
  };
}

void main() {
  test('aller-retour exact via SharedPreferences', () async {
    final depart = _exemple();
    SharedPreferences.setMockInitialValues({
      ...depart,
      'parent_pin': '9876',
    });
    final prefs = await SharedPreferences.getInstance();
    final texte = await sauvegardeActuelle(prefs);
    expect(texte.contains('9876'), isFalse);
    expect(texte.contains('parent_pin'), isFalse);

    // On abîme l'état, puis on restaure.
    await prefs.setInt('emile_diamonds', 1);
    await prefs.setBool('Ma leçon_star_quiz', true);
    await prefs.setString('parent_pin', '1111');
    await prefs.setBool('Autre_star_train', true); // absente de la sauvegarde
    final v = validerSauvegarde(texte);
    expect(v.diamants, 123);
    expect(v.nbLecons, 1);
    await appliquerSauvegarde(v, prefs);

    final apres = valeursSauvegardables(prefs);
    expect(apres, depart);
    expect(prefs.getString('parent_pin'), '1111'); // PIN intact
    // Copie de secours de l'état d'avant.
    final secours = validerSauvegarde(prefs.getString(kCleAvantRestauration)!);
    expect(secours.diamants, 1);
  });

  test('le PIN n\'est jamais inclus, même si on le donne', () {
    final t = construireSauvegarde({..._exemple(), 'parent_pin': '4242'});
    expect(t.contains('4242'), isFalse);
    // Un PIN glissé dans une sauvegarde est ignoré à la lecture.
    final j = jsonDecode(t) as Map<String, dynamic>;
    (j['prefs'] as Map<String, dynamic>)['parent_pin'] = '4242';
    expect(validerSauvegarde(jsonEncode(j)).valeurs.containsKey('parent_pin'),
        isFalse);
  });

  test('JSON invalide, version inconnue, types faux : refusés', () {
    expect(() => validerSauvegarde('pas du json'), throwsFormatException);
    expect(() => validerSauvegarde('[1,2]'), throwsFormatException);
    expect(
      () => validerSauvegarde(jsonEncode({'sauvegardeVersion': 2, 'prefs': {}})),
      throwsFormatException,
    );
    expect(() => validerSauvegarde(jsonEncode({'prefs': {}})),
        throwsFormatException);
    for (final faux in <Map<String, Object?>>[
      {'emile_diamonds': 'beaucoup'},
      {'emile_diamonds': -3},
      {'reglage_sons': 1},
      {'seance_vus_X': [1, 2]},
      {'custom_lessons': 'pas du json'},
      {'memoire_v1': '{"version":99}'},
      {'X_star_quiz': 'oui'},
    ]) {
      expect(
        () => validerSauvegarde(
          jsonEncode({'sauvegardeVersion': 1, 'prefs': faux}),
        ),
        throwsFormatException,
        reason: '$faux',
      );
    }
  });

  test('en cas d\'erreur, rien n\'est modifié', () async {
    SharedPreferences.setMockInitialValues({'emile_diamonds': 7});
    final prefs = await SharedPreferences.getInstance();
    expect(
      () => validerSauvegarde('{"sauvegardeVersion":1,"prefs":{"emile_diamonds":"x"}}'),
      throwsFormatException,
    );
    expect(prefs.getInt('emile_diamonds'), 7);
    expect(prefs.containsKey(kCleAvantRestauration), isFalse);
  });

  test('résumé : leçons, niveau, diamants', () {
    final v = validerSauvegarde(construireSauvegarde(_exemple()));
    expect(v.resume, contains('1 leçon importée'));
    expect(v.resume, contains('123 diamants'));
    expect(v.resume, contains('niveau ${v.niveau}'));
  });

  test('la clé Gemini n\'est jamais incluse et succes est conservé', () async {
    const lecon = LessonModel(
      titre: 'Test',
      succes: '🚀 Pilote',
      astuces: [],
      exercices: [],
      quiz: [],
    );
    SharedPreferences.setMockInitialValues({
      kCleGeminiPrefs: 'AIzaSecretGeminiKey1234',
      LaboSyncService.kCleSessionFirebase: '{"refreshToken":"secret-rt"}',
      LaboSyncService.kCleMetaSync: '{"diamantsModifieLe":"2026-11-17"}',
      'custom_lessons': jsonEncode({
        'Maths': [lecon.toJson()],
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final t = await sauvegardeActuelle(prefs);
    expect(t.contains('AIzaSecretGeminiKey1234'), isFalse);
    expect(t.contains(kCleGeminiPrefs), isFalse);
    expect(t.contains('secret-rt'), isFalse);
    expect(t.contains(LaboSyncService.kCleSessionFirebase), isFalse);
    expect(t.contains(LaboSyncService.kCleMetaSync), isFalse);
    expect(t.contains('🚀 Pilote'), isTrue);

    final v = validerSauvegarde(t);
    final custom = jsonDecode(v.valeurs['custom_lessons'] as String)
        as Map<String, dynamic>;
    final l2 = LessonModel.fromJson(
      (custom['Maths'] as List).first as Map<String, dynamic>,
    );
    expect(l2.succes, '🚀 Pilote');
  });
}

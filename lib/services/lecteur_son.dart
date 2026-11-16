import 'dart:typed_data';

// Choix du moteur de lecture selon la plateforme (import conditionnel) :
//  - Android et web : plugin audioplayers ;
//  - Windows : appel direct à winmm.dll (PlaySound), sans DLL de plugin
//    (Smart App Control bloque les DLL de plugins Flutter non signées).
export 'lecteur_son_web.dart' if (dart.library.io) 'lecteur_son_io.dart';

/// Moteurs de lecture possibles.
enum MoteurSon { audioplayers, winmm }

/// Choix pur (testable) du moteur : winmm sous Windows, audioplayers ailleurs.
MoteurSon choisirMoteurSon({required bool windows}) =>
    windows ? MoteurSon.winmm : MoteurSon.audioplayers;

/// Lecteur de sons WAV en mémoire.
abstract class LecteurSon {
  /// Joue [wav] (WAV PCM complet, en-tête compris) en coupant le son en cours.
  Future<void> jouer(Uint8List wav);
  void dispose();
}

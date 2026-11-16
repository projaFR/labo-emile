import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'lecteur_son.dart';
import 'lecteur_audioplayers.dart';

LecteurSon creerLecteurSon() =>
    choisirMoteurSon(windows: Platform.isWindows) == MoteurSon.winmm
        ? LecteurWinmm()
        : LecteurAudioplayers();

typedef _PlaySoundC = Int32 Function(Pointer<Void>, Pointer<Void>, Uint32);
typedef _PlaySoundDart = int Function(Pointer<Void>, Pointer<Void>, int);

/// Lecture d'un WAV en mémoire par PlaySound (winmm.dll, fournie par Windows).
/// SND_ASYNC (1) | SND_NODEFAULT (2) | SND_MEMORY (4). Le tampon natif doit
/// rester valide pendant la lecture : on le garde jusqu'au son suivant.
class LecteurWinmm implements LecteurSon {
  static const int _flags = 1 | 2 | 4;
  _PlaySoundDart? _playSound;
  Pointer<Uint8>? _tampon;

  _PlaySoundDart _charger() => _playSound ??= DynamicLibrary.open('winmm.dll')
      .lookupFunction<_PlaySoundC, _PlaySoundDart>('PlaySoundW');

  @override
  Future<void> jouer(Uint8List wav) async {
    final f = _charger();
    f(nullptr, nullptr, 0); // arrête le son en cours
    _liberer();
    final p = malloc<Uint8>(wav.length);
    p.asTypedList(wav.length).setAll(0, wav);
    _tampon = p;
    f(p.cast<Void>(), nullptr, _flags);
  }

  void _liberer() {
    final p = _tampon;
    if (p != null) {
      malloc.free(p);
      _tampon = null;
    }
  }

  @override
  void dispose() {
    final f = _playSound;
    if (f != null) f(nullptr, nullptr, 0);
    _liberer();
  }
}

import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'lecteur_son.dart';

/// Lecture via le plugin audioplayers (Android, web). Le lecteur n'est créé
/// qu'au premier son : sous Windows cette classe n'est jamais utilisée.
class LecteurAudioplayers implements LecteurSon {
  AudioPlayer? _player;

  @override
  Future<void> jouer(Uint8List wav) async {
    final p = _player ??= AudioPlayer();
    await p.stop();
    await p.play(BytesSource(wav));
  }

  @override
  void dispose() => _player?.dispose();
}

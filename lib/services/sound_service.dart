import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Service singleton de sons synthétiques.
/// Génère des sons WAV en mémoire — aucun fichier asset, aucune connexion réseau.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;

  bool get enabled => _enabled;
  void setEnabled(bool value) => _enabled = value;

  // ── Génération WAV synthétique ─────────────────────────────────────────────

  /// Génère un buffer WAV PCM 16 bits, mono, 22050 Hz.
  /// [notes] : liste de (fréquence Hz, durée ms)
  Uint8List _generateWav(List<(double, int)> notes, {double volume = 0.6}) {
    const int sampleRate = 22050;
    final List<int> samples = [];

    for (final (freq, durationMs) in notes) {
      final int numSamples = (sampleRate * durationMs / 1000).round();
      for (int i = 0; i < numSamples; i++) {
        // Oscillateur sinus avec envelope (fade out)
        final double t = i / sampleRate;
        final double envelope = 1.0 - (i / numSamples);
        final double sample = sin(2 * pi * freq * t) * envelope * volume;
        final int pcm = (sample * 32767).clamp(-32768, 32767).toInt();
        samples.add(pcm & 0xFF);
        samples.add((pcm >> 8) & 0xFF);
      }
    }

    // Header WAV
    final int dataSize = samples.length;
    final ByteData header = ByteData(44);
    // RIFF
    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    // fmt
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, 1, Endian.little); // mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    // data
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    final Uint8List result = Uint8List(44 + dataSize);
    result.setRange(0, 44, header.buffer.asUint8List());
    result.setRange(44, 44 + dataSize, samples);
    return result;
  }

  Future<void> _play(Uint8List wav) async {
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(BytesSource(wav));
    } catch (_) {}
  }

  // ── Sons publics ───────────────────────────────────────────────────────────

  /// ✅ Bonne réponse : deux notes montantes joyeuses
  Future<void> playSuccess() => _play(
    _generateWav([
      (523.25, 80), // Do5
      (659.25, 150), // Mi5
    ], volume: 0.5),
  );

  /// ❌ Mauvaise réponse : note grave descendante
  Future<void> playError() => _play(
    _generateWav([
      (293.66, 80), // Ré4
      (220.00, 180), // La3
    ], volume: 0.4),
  );

  /// ⭐ Étoile débloquée : trois notes festives
  Future<void> playStar() => _play(
    _generateWav([
      (523.25, 80), // Do5
      (659.25, 80), // Mi5
      (783.99, 200), // Sol5
    ], volume: 0.6),
  );

  /// 🏆 Score parfait : fanfare courte
  Future<void> playPerfect() => _play(
    _generateWav([
      (523.25, 80),
      (659.25, 80),
      (783.99, 80),
      (1046.50, 300),
    ], volume: 0.6),
  );

  void dispose() => _player.dispose();
}

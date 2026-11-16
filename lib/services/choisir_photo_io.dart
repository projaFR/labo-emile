import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'gemini_lecon_service.dart';

const MethodChannel _canalPhoto = MethodChannel('fr.thibaut.laboemile/photo');

bool get peutPrendrePhoto => Platform.isAndroid;
bool get peutChoisirImage => Platform.isAndroid || Platform.isWindows;

/// Prend une photo avec l'appareil photo du téléphone (Android uniquement).
Future<PhotoLecon?> prendrePhotoAppareil() async {
  if (!Platform.isAndroid) return null;
  try {
    final bytes = await _canalPhoto.invokeMethod<Uint8List>('prendrePhoto');
    if (bytes == null || bytes.isEmpty) return null;
    return PhotoLecon(
      octets: bytes,
      mimeType: detecterMimeType('photo.jpg', bytes),
      nom: 'Photo appareil',
    );
  } on PlatformException catch (e) {
    throw ErreurGeminiLecon(
      e.message ?? "Impossible d'ouvrir l'appareil photo.",
    );
  }
}

/// Choisit une ou plusieurs images depuis la galerie (Android) ou le PC (Windows).
Future<List<PhotoLecon>> choisirImagesAppareil() async {
  if (Platform.isAndroid) {
    try {
      final bytes = await _canalPhoto.invokeMethod<Uint8List>('choisirGalerie');
      if (bytes == null || bytes.isEmpty) return const [];
      return [
        PhotoLecon(
          octets: bytes,
          mimeType: detecterMimeType('image.jpg', bytes),
          nom: 'Image galerie',
        ),
      ];
    } on PlatformException catch (e) {
      throw ErreurGeminiLecon(
        e.message ?? "Impossible d'ouvrir la galerie.",
      );
    }
  }
  if (Platform.isWindows) {
    return _choisirImagesWindows();
  }
  return const [];
}

Future<List<PhotoLecon>> _choisirImagesWindows() async {
  const script =
      '[Console]::OutputEncoding = [System.Text.Encoding]::UTF8;'
      '[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null;'
      r'$d = New-Object System.Windows.Forms.OpenFileDialog;'
      r'$d.Title = "Choisir une photo de la lecon";'
      r'$d.Filter = "Images (*.jpg;*.jpeg;*.png;*.webp)|*.jpg;*.jpeg;*.png;*.webp|Tous les fichiers (*.*)|*.*";'
      r'$d.Multiselect = $true;'
      r'if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {'
      r'  $d.FileNames | ForEach-Object { [Console]::WriteLine($_) }'
      '}';
  try {
    final res = await Process.run(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-Command', script],
      stdoutEncoding: utf8,
    );
    if (res.exitCode != 0) return const [];
    final lignes = const LineSplitter().convert(res.stdout.toString().trim());
    final sorties = <PhotoLecon>[];
    for (final chemin in lignes) {
      if (sorties.length >= 3) break;
      final propre = chemin.trim();
      if (propre.isEmpty) continue;
      final f = File(propre);
      if (!f.existsSync()) continue;
      final octets = await f.readAsBytes();
      if (octets.isEmpty) continue;
      final nom = f.uri.pathSegments.isNotEmpty
          ? f.uri.pathSegments.last
          : 'image.jpg';
      sorties.add(
        PhotoLecon(
          octets: octets,
          mimeType: detecterMimeType(nom, octets),
          nom: nom,
        ),
      );
    }
    return sorties;
  } catch (_) {
    return const [];
  }
}

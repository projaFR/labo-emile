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
      final brut = await f.readAsBytes();
      if (brut.isEmpty) continue;
      final octets = await _reduireImageWindowsSiBesoin(propre, brut);
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

Future<Uint8List> _reduireImageWindowsSiBesoin(
  String chemin,
  Uint8List brut,
) async {
  if (brut.length <= 600 * 1024) return brut;
  const script = r'''
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile($env:LABO_IMG_PATH)
try {
  $max = 1600
  $w = $src.Width
  $h = $src.Height
  if ($w -gt $max -or $h -gt $max) {
    $ratio = [Math]::Min($max / $w, $max / $h)
    $nw = [Math]::Max(1, [int][Math]::Round($w * $ratio))
    $nh = [Math]::Max(1, [int][Math]::Round($h * $ratio))
  } else {
    $nw = $w
    $nh = $h
  }
  $bmp = New-Object System.Drawing.Bitmap($nw, $nh)
  try {
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
      $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $g.DrawImage($src, 0, 0, $nw, $nh)
    } finally {
      $g.Dispose()
    }
    $ms = New-Object System.IO.MemoryStream
    try {
      $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
        Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
      $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
      $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
        [System.Drawing.Imaging.Encoder]::Quality, [long]85
      )
      $bmp.Save($ms, $codec, $ep)
      [Convert]::ToBase64String($ms.ToArray())
    } finally {
      $ms.Dispose()
    }
  } finally {
    $bmp.Dispose()
  }
} finally {
  $src.Dispose()
}
''';
  try {
    final res = await Process.run(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-Command', script],
      environment: {'LABO_IMG_PATH': chemin},
      stdoutEncoding: utf8,
    ).timeout(const Duration(seconds: 15));
    if (res.exitCode != 0) return brut;
    final b64 = (res.stdout as String).trim();
    if (b64.isEmpty) return brut;
    final reduit = base64Decode(b64);
    return (reduit.isNotEmpty && reduit.length < brut.length) ? reduit : brut;
  } catch (_) {
    return brut;
  }
}

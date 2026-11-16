import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'ouvrir_lien.dart';

/// Ouvre [url] : sous Windows par `cmd /c start`, ailleurs par url_launcher.
Future<bool> ouvrirLien(String url) async {
  try {
    if (Platform.isWindows) {
      if (!lienSurPourCmd(url)) return false;
      final res = await Process.run('cmd', argumentsCmdStart(url));
      return res.exitCode == 0;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {}
  return false;
}

import 'package:url_launcher/url_launcher.dart';

/// Ouvre [url] dans le navigateur (url_launcher).
Future<bool> ouvrirLien(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}

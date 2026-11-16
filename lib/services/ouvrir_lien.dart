// Ouverture d'un lien (import conditionnel) :
//  - Windows : `cmd /c start` (sans DLL de plugin, voir README) ;
//  - Android et web : plugin url_launcher.
export 'ouvrir_lien_web.dart' if (dart.library.io) 'ouvrir_lien_io.dart';

/// Vrai si [url] peut être confié à `cmd /c start` sans risque : http(s)
/// seulement, et aucun caractère spécial de cmd (& | < > ^ guillemet, espaces).
bool lienSurPourCmd(String url) =>
    RegExp(r'^https?://[^\s&|<>^"]+$').hasMatch(url);

/// Arguments passés à `cmd` pour ouvrir [url].
List<String> argumentsCmdStart(String url) => ['/c', 'start', '', url];

// Sélection / prise de photo selon la plateforme :
//  - Android : appareil photo et galerie via MethodChannel natif sans plugin tiers.
//  - Windows : boîte de dialogue native via PowerShell (aucune DLL, compatible SAC).
//  - Web : non pris en charge (import JSON manuel conservé).
export 'choisir_photo_web.dart' if (dart.library.io) 'choisir_photo_io.dart';
export 'gemini_lecon_service.dart' show detecterMimeType;

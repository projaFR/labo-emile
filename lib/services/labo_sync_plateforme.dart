// Fonctions de synchronisation dépendantes de `dart:io` (import conditionnel) :
//  - Android et Windows : lecture de config locale, serveur loopback OAuth et ADB ;
//  - Web / iPad : repli sans `dart:io` (connexion par code copié depuis le PC).
export 'labo_sync_plateforme_web.dart'
    if (dart.library.io) 'labo_sync_plateforme_io.dart';

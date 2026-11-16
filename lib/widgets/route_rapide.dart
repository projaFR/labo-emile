import 'package:flutter/material.dart';

/// Page qui s'ouvre et se ferme vite (150 ms au lieu de 300 ms).
/// Pendant la fermeture d'une page, Flutter ignore les appuis sur la page
/// de dessous : plus c'est court, moins un enfant qui tape vite est ignoré.
class RouteRapide<T> extends MaterialPageRoute<T> {
  RouteRapide({required super.builder});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 150);
}

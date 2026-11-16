import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

/// Demande le code parent. Renvoie true si l'accès est accordé.
/// Première fois (aucun PIN enregistré) : propose d'en créer un.
/// Utilisé par l'engrenage (Espace Parent) et par « Ajouter une leçon ».
Future<bool> demanderCodeParent(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return false;
  final String? savedPin = prefs.getString('parent_pin');
  final ok = savedPin == null
      ? await _creerPin(context, prefs)
      : await _verifierPin(context, prefs);
  return ok ?? false;
}

Future<bool?> _creerPin(BuildContext context, SharedPreferences prefs) {
  final controller = TextEditingController();
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text("🆕 Code PIN Parent"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Choisis un code secret à 4 chiffres."),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            autofocus: true,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: "••••",
              counterText: "",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("ANNULER", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () async {
            final pin = controller.text.trim();
            if (pin.length == 4 && int.tryParse(pin) != null) {
              await prefs.setString('parent_pin', pin);
              if (context.mounted) Navigator.pop(context, true);
            }
          },
          child: const Text("CRÉER"),
        ),
      ],
    ),
  );
}

Future<bool?> _verifierPin(BuildContext context, SharedPreferences prefs) {
  final controller = TextEditingController();
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text("🔒 Accès Parent"),
      content: TextField(
        controller: controller,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 4,
        autofocus: true,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          hintText: "••••",
          counterText: "",
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("ANNULER", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            final actualPin = prefs.getString('parent_pin') ?? "1234";
            final bon = controller.text == actualPin;
            Navigator.pop(context, bon);
            if (!bon) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Code incorrect"),
                  backgroundColor: LaboPalette.rouge,
                ),
              );
            }
          },
          child: const Text("VALIDER"),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

import '../services/gemini_key_store.dart';
import '../services/ouvrir_lien.dart';
import '../theme.dart';

/// Boîte de dialogue partagée pour saisir, modifier ou effacer la clé Gemini
/// gratuite. Retourne `(modifie: true, cle: ...)` si un changement a eu lieu.
Future<({bool modifie, String? cle})> demanderEtEnregistrerCleGemini(
  BuildContext context, {
  String? cleActuelle,
  bool autoriserEffacement = false,
}) async {
  final controller = TextEditingController(text: cleActuelle ?? '');
  var masquer = true;
  final resultat = await showDialog<({bool effacer, String valeur})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('✨ Clé Gemini gratuite'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Colle ta clé API Google AI Studio (gratuite) pour fabriquer '
                'des leçons directement depuis une photo.',
                style: TextStyle(fontSize: 13, color: LaboPalette.muted),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    ouvrirLien('https://aistudio.google.com/apikey'),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Obtenir une clé gratuite'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: masquer,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Clé API Gemini',
                  hintText: 'AIza...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      masquer ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setDialogState(() => masquer = !masquer),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (autoriserEffacement && cleActuelle != null)
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, (effacer: true, valeur: '')),
              child: const Text(
                'EFFACER',
                style: TextStyle(color: LaboPalette.rouge),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'ANNULER',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              ctx,
              (effacer: false, valeur: controller.text.trim()),
            ),
            child: const Text('ENREGISTRER'),
          ),
        ],
      ),
    ),
  );

  if (resultat == null) return (modifie: false, cle: cleActuelle);
  final nouvelle = resultat.effacer ? '' : resultat.valeur;
  await enregistrerCleGemini(nouvelle);
  return (modifie: true, cle: nouvelle.isEmpty ? null : nouvelle);
}

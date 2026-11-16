import 'package:flutter/material.dart';

import '../services/labo_firebase_auth.dart';
import '../services/labo_sync_service.dart';
import '../theme.dart';

/// Dialogue de configuration de la synchronisation Firebase (téléphone ↔ PC).
Future<bool> ouvrirDialogueSyncFirebase(BuildContext context) async {
  final sync = LaboSyncService();
  final cleController = TextEditingController(text: sync.webApiKeyActuelle);
  final emailController = TextEditingController(text: sync.emailCompte ?? '');
  final mdpController = TextEditingController();
  var masquerMdp = true;
  var enCours = false;
  String? erreur;

  final resultat = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('☁️ Synchronisation Firebase'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Connecte le même compte Labo sur le téléphone et sur le PC '
                'pour partager automatiquement les leçons et les progrès.',
                style: TextStyle(fontSize: 13, color: LaboPalette.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cleController,
                enabled: !enCours,
                minLines: 1,
                maxLines: 3,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Clé API Web Firebase (ou JSON de config)',
                  hintText: 'AIza...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                enabled: !enCours,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'E-mail du compte Labo',
                  hintText: 'labo@emile.local',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: mdpController,
                enabled: !enCours,
                obscureText: masquerMdp,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      masquerMdp ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setDialogState(() => masquerMdp = !masquerMdp),
                  ),
                ),
              ),
              if (enCours) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Connexion et synchronisation…',
                        style: TextStyle(
                          fontSize: 13,
                          color: LaboPalette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (erreur != null) ...[
                const SizedBox(height: 10),
                Text(
                  erreur!,
                  style: const TextStyle(
                    color: LaboPalette.rouge,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (sync.estConfigure)
            TextButton(
              onPressed: enCours
                  ? null
                  : () async {
                      await sync.deconnecterCompte();
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    },
              child: const Text(
                'DÉCONNECTER',
                style: TextStyle(color: LaboPalette.rouge),
              ),
            ),
          TextButton(
            onPressed: enCours ? null : () => Navigator.pop(ctx, false),
            child: const Text(
              'ANNULER',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: enCours
                ? null
                : () async {
                    setDialogState(() {
                      enCours = true;
                      erreur = null;
                    });
                    try {
                      final cfg = extraireCleOuJsonFirebase(
                        cleController.text,
                        projectIdDefaut: sync.projectIdActuel,
                      );
                      await sync.connecterCompte(
                        projectId: cfg.projectId,
                        webApiKey: cfg.webApiKey,
                        email: emailController.text,
                        motDePasse: mdpController.text,
                      );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } on ErreurSyncLabo catch (e) {
                      setDialogState(() {
                        enCours = false;
                        erreur = e.message;
                      });
                    } catch (_) {
                      setDialogState(() {
                        enCours = false;
                        erreur = 'Connexion impossible.';
                      });
                    }
                  },
            child: const Text('CONNECTER'),
          ),
        ],
      ),
    ),
  );

  return resultat ?? false;
}

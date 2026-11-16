import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_service.dart';

class ParentView extends StatefulWidget {
  final int currentDiamonds;
  final Function(int) onDiamondsChanged;
  final VoidCallback onClearDiamonds;
  /// Titres de toutes les leçons (pour la suppression).
  final List<String> titresLecons;
  final void Function(String titre) onDeleteLesson;

  /// Texte d'information sur la mémoire par question.
  final String Function() infoMemoire;

  /// Efface la mémoire par question (jamais les diamants ni les leçons).
  final Future<void> Function() onResetMemoire;

  const ParentView({
    super.key,
    required this.currentDiamonds,
    required this.onDiamondsChanged,
    required this.onClearDiamonds,
    required this.titresLecons,
    required this.onDeleteLesson,
    required this.infoMemoire,
    required this.onResetMemoire,
  });

  @override
  State<ParentView> createState() => _ParentViewState();
}

class _ParentViewState extends State<ParentView> {
  late String? _titreASupprimer =
      widget.titresLecons.isEmpty ? null : widget.titresLecons.first;

  void _changePinCodeDialog() {
    final TextEditingController newPinController = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("🔐 Nouveau Code PIN"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Choisis un nouveau code secret à 4 chiffres :",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                    decoration: InputDecoration(
                      hintText: "••••",
                      counterText: "",
                      errorText: dialogError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "ANNULER",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newPin = newPinController.text.trim();
                    if (newPin.length == 4 && int.tryParse(newPin) != null) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('parent_pin', newPin);
                      if (context.mounted) Navigator.pop(context);
                    } else {
                      setDialogState(() {
                        dialogError = "Le code doit faire 4 chiffres !";
                      });
                    }
                  },
                  child: const Text("ENREGISTRER"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmerResetMemoire() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("🧠 Réinitialiser la mémoire ?"),
        content: const Text(
          "Le Labo oubliera quelles questions Émile a réussies ou ratées "
          "(la Révision du jour repart de zéro).\n\n"
          "Les diamants, les étoiles et les leçons ne changent pas.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("ANNULER", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              "RÉINITIALISER",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.onResetMemoire();
      if (mounted) setState(() {});
    }
  }

  Future<void> _confirmerSuppression() async {
    final titre = _titreASupprimer;
    if (titre == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer cette leçon ?"),
        content: Text("« $titre » sera retirée du Labo."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("ANNULER", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("SUPPRIMER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) widget.onDeleteLesson(titre);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text("⚙️", style: TextStyle(fontSize: 24)),
                    SizedBox(width: 8),
                    Text(
                      "Espace Administration",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: LaboPalette.ink,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.lock_reset,
                    color: LaboPalette.encre,
                    size: 28,
                  ),
                  onPressed: _changePinCodeDialog,
                ),
              ],
            ),
            const Divider(height: 20),
            const Text(
              "💎 Récompenses d'Émile",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: LaboPalette.muted,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () =>
                      widget.onDiamondsChanged(10), // ✅ envoie +10 relatif
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    "Donner +10 💎",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LaboPalette.good,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: widget.onClearDiamonds,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text(
                    "Remettre à 0 💎",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            const Text(
              "🧠 Mémoire d'Émile",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: LaboPalette.muted,
              ),
            ),
            const SizedBox(height: 6),
            Text(widget.infoMemoire(), style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _confirmerResetMemoire,
                icon: const Icon(Icons.psychology_alt, color: LaboPalette.rouge),
                label: const Text(
                  "Réinitialiser la mémoire",
                  style: TextStyle(color: LaboPalette.rouge),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: LaboPalette.rouge),
                ),
              ),
            ),
            const Divider(height: 30),
            const Text(
              "🎚️ Réglages d'Émile",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: LaboPalette.muted,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("🔊 Sons"),
              value: SettingsService().sons,
              onChanged: (v) async {
                await SettingsService().setSons(v);
                setState(() {});
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("📳 Vibrations"),
              value: SettingsService().vibrations,
              onChanged: (v) async {
                await SettingsService().setVibrations(v);
                setState(() {});
              },
            ),
            const Text("⏳ Temps par question du Défi Chrono"),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final s in SettingsService.chronoPermis)
                  ChoiceChip(
                    label: Text(s == 0 ? "Sans chrono" : "$s s"),
                    selected: SettingsService().chronoSecondes == s,
                    onSelected: (_) async {
                      await SettingsService().setChrono(s);
                      setState(() {});
                    },
                  ),
              ],
            ),
            const Divider(height: 40),
            const Text(
              "🚨 Zone de danger",
              style: TextStyle(fontWeight: FontWeight.bold, color: LaboPalette.rouge),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              isExpanded: true,
              value: _titreASupprimer,
              hint: const Text("Aucune leçon"),
              items: [
                for (final t in widget.titresLecons)
                  DropdownMenuItem(
                    value: t,
                    child: Text(t, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _titreASupprimer = v),
            ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _titreASupprimer == null ? null : _confirmerSuppression,
                icon: const Icon(Icons.delete_forever, color: LaboPalette.rouge),
                label: const Text(
                  "Supprimer cette leçon",
                  style: TextStyle(color: LaboPalette.rouge),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: LaboPalette.rouge),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

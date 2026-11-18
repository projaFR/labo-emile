import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/accueil_logic.dart';
import '../logic/memoire.dart';
import '../logic/sauvegarde.dart';
import '../logic/suivi_parent_logic.dart';
import '../models/lesson_model.dart';
import '../version.dart';
import '../theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gemini_key_store.dart';
import '../services/labo_sync_service.dart';
import '../services/questions_masquees_service.dart';
import '../services/settings_service.dart';
import '../widgets/dialogue_cle_gemini.dart';
import '../widgets/dialogue_sync_firebase.dart';
import 'exercise_view.dart';

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

  /// Appelée après une restauration réussie : recharge tout l'état.
  final Future<void> Function() onRestauree;

  final List<LeconRef> lecons;
  final Memoire? memoire;

  const ParentView({
    super.key,
    required this.currentDiamonds,
    required this.onDiamondsChanged,
    required this.onClearDiamonds,
    required this.titresLecons,
    required this.onDeleteLesson,
    required this.infoMemoire,
    required this.onResetMemoire,
    required this.onRestauree,
    this.lecons = const [],
    this.memoire,
  });

  @override
  State<ParentView> createState() => _ParentViewState();
}

class _ParentViewState extends State<ParentView> {
  late String? _titreASupprimer =
      widget.titresLecons.isEmpty ? null : widget.titresLecons.first;
  late int _diamantsAffiches = widget.currentDiamonds;
  String? _cleGemini;
  bool _envoiUsbEnCours = false;

  @override
  void initState() {
    super.initState();
    _chargerCleGemini();
  }

  Future<void> _chargerCleGemini() async {
    final cle = await lireCleGemini();
    if (mounted) setState(() => _cleGemini = cle);
  }

  static const LessonModel _leconDemoTest = LessonModel(
    titre: '🎮 Démo : tous les types',
    astuces: [],
    exercices: [
      ExerciseModel(
        question: '14 x 4 = ([?] x 4) + ([?] x 4)',
        consigne: 'Calcul à trous :',
        reponsesMultiples: ['10', '4'],
        astuceErreur: '14 = 10 + 4.',
      ),
      ExerciseModel(
        question: 'Combien de faces a un cube ?',
        consigne: 'QCM :',
        options: ['4', '6', '8', '12'],
        reponseAttendue: '6',
        astuceErreur: 'Compte comme sur un dé.',
      ),
      ExerciseModel(
        typeExplicite: 'saisieMot',
        question: 'Des [?] (hibou)',
        consigne: 'Mot à écrire :',
        reponseAttendue: 'hiboux',
        reponsesAcceptees: ['des hiboux'],
        astuceErreur: 'Pense aux 7 exceptions en -ou.',
        explication: 'Hibou prend un -x au pluriel.',
      ),
      ExerciseModel(
        typeExplicite: 'vraiFaux',
        question: 'Un pavé droit a 6 faces rectangulaires.',
        consigne: 'Vrai ou Faux ?',
        options: ['Vrai', 'Faux'],
        reponseAttendue: 'Vrai',
        astuceErreur: 'Pense à une boîte à chaussures.',
      ),
      ExerciseModel(
        typeExplicite: 'ordre',
        question: 'Range ces nombres du plus petit au plus grand :',
        consigne: 'Remets dans l’ordre :',
        reponsesMultiples: ['18', '45', '102', '340'],
        astuceErreur: 'Compare d’abord les centaines.',
      ),
      ExerciseModel(
        typeExplicite: 'association',
        question: 'Relie chaque multiplication à son résultat :',
        consigne: 'Associe les paires :',
        options: ['3 x 4', '5 x 5', '2 x 9'],
        reponsesMultiples: ['12', '25', '18'],
        astuceErreur: 'Révise les tables de 2, 3 et 5.',
      ),
      ExerciseModel(
        typeExplicite: 'classement',
        question: 'Classe ces mots selon leur nature :',
        consigne: 'Range dans la bonne boîte :',
        options: ['chien', 'courir', 'table', 'sauter'],
        reponsesMultiples: ['Nom', 'Verbe', 'Nom', 'Verbe'],
        astuceErreur: 'Le verbe indique une action.',
      ),
    ],
    quiz: [],
  );

  Future<void> _ouvrirTestExercices() async {
    final choix = await showDialog<LessonModel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text("🧪 Choisir une leçon à tester"),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, _leconDemoTest),
            child: const Text(
              "🎮 Démo : tous les types d'exercices (7 ex.)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          for (final ref in widget.lecons)
            if (ref.lecon.exercices.isNotEmpty)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, ref.lecon),
                child: Text(
                  "${ref.lecon.titre} (${ref.lecon.exercices.length} ex.)",
                ),
              ),
        ],
      ),
    );
    if (choix == null || !mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text("🧪 Test : ${choix.titre}")),
          body: ExerciseView(
            lesson: choix,
            modeTestParent: true,
            onSuccess: () {},
            onFailure: () {},
            onPerfectScore: () {},
          ),
        ),
      ),
    );
  }

  Future<void> _ouvrirSuiviDetaille() async {
    final mem = widget.memoire;
    if (mem == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final masquees = QuestionsMasqueesService().masquees;
          final resumes = calculerResumesLecons(
            widget.lecons,
            mem,
            masquees: masquees,
          );
          final topRatees = topQuestionsRatees(
            widget.lecons,
            mem,
            masquees: masquees,
          );
          final listeMasquees = listerQuestionsMasquees(
            widget.lecons,
            mem,
            masquees,
          );

          return AlertDialog(
            title: const Text("📊 Suivi détaillé d'Émile"),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Maîtrise par leçon",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: LaboPalette.encre,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (resumes.isEmpty)
                      const Text(
                        "Aucune leçon pour l'instant.",
                        style: TextStyle(color: LaboPalette.muted, fontSize: 13),
                      )
                    else
                      for (final r in resumes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.titre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "${r.maitrisees}/${r.totalQuestions} (${r.pourcentageMaitrise}%)",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: LaboPalette.muted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: r.totalQuestions == 0
                                      ? 0
                                      : r.maitrisees / r.totalQuestions,
                                  minHeight: 6,
                                  backgroundColor: LaboPalette.paper,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    LaboPalette.good,
                                  ),
                                ),
                              ),
                              if (r.aRevoir > 0)
                                Text(
                                  "${r.aRevoir} à revoir aujourd'hui",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: LaboPalette.warn,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    const Divider(height: 20),
                    const Text(
                      "Questions les plus ratées",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: LaboPalette.encre,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (topRatees.isEmpty)
                      const Text(
                        "Aucune erreur enregistrée pour l'instant.",
                        style: TextStyle(color: LaboPalette.muted, fontSize: 13),
                      )
                    else
                      for (final q in topRatees)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            q.texteQuestion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            "${q.titreLecon} · ${q.ratees} erreur${q.ratees > 1 ? 's' : ''}",
                            style: const TextStyle(
                              fontSize: 11,
                              color: LaboPalette.rouge,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: "Masquer cette question (erreur IA)",
                            icon: const Icon(
                              Icons.flag_outlined,
                              size: 18,
                              color: LaboPalette.muted,
                            ),
                            onPressed: () async {
                              await QuestionsMasqueesService().masquer(q.cle);
                              setDlgState(() {});
                            },
                          ),
                        ),
                    if (listeMasquees.isNotEmpty) ...[
                      const Divider(height: 20),
                      const Text(
                        "Questions masquées",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: LaboPalette.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final q in listeMasquees)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            q.texteQuestion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          subtitle: Text(
                            q.titreLecon,
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              await QuestionsMasqueesService().demasquer(q.cle);
                              setDlgState(() {});
                            },
                            child: const Text("Réafficher"),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("FERMER"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _configurerCleGemini() async {
    final res = await demanderEtEnregistrerCleGemini(
      context,
      cleActuelle: _cleGemini,
      autoriserEffacement: true,
    );
    if (!res.modifie || !mounted) return;
    setState(() => _cleGemini = res.cle);
    _message(
      res.cle == null
          ? "Clé Gemini effacée."
          : "Clé Gemini enregistrée sur cet appareil.",
    );
  }

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

  void _message(String texte, {bool erreur = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texte),
        backgroundColor: erreur ? LaboPalette.rouge : LaboPalette.good,
      ),
    );
  }

  Future<void> _copierSauvegarde() async {
    final texte = await sauvegardeActuelle();
    await Clipboard.setData(ClipboardData(text: texte));
    if (!mounted) return;
    _message("Sauvegarde copiée. Colle-la dans une note ou un message.");
  }

  Future<void> _restaurerSauvegarde() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final controller = TextEditingController(text: data?.text ?? '');
    final texte = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Restaurer une sauvegarde"),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: "Colle ici le texte de la sauvegarde",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ANNULER"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text("VÉRIFIER"),
          ),
        ],
      ),
    );
    if (texte == null || !mounted) return;
    final SauvegardeValide valide;
    try {
      valide = validerSauvegarde(texte);
    } on FormatException catch (e) {
      _message("${e.message} Rien n'a été modifié.", erreur: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remplacer la progression ?"),
        content: Text(
          "Cette sauvegarde contient : ${valide.resume}.\n\n"
          "La progression actuelle sera remplacée (une copie de secours est "
          "gardée).",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("ANNULER"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("RESTAURER"),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await appliquerSauvegarde(valide);
      await widget.onRestauree();
    } catch (_) {
      if (mounted) _message("La restauration a échoué.", erreur: true);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
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
            Text(
              "💎 Récompenses d'Émile (solde : $_diamantsAffiches 💎)",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: LaboPalette.muted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _diamantsAffiches <= 0
                      ? null
                      : () {
                          widget.onDiamondsChanged(-1);
                          setState(() {
                            _diamantsAffiches =
                                (_diamantsAffiches - 1).clamp(0, 999999);
                          });
                        },
                  child: const Text("-1 💎"),
                ),
                OutlinedButton(
                  onPressed: _diamantsAffiches <= 0
                      ? null
                      : () {
                          widget.onDiamondsChanged(-5);
                          setState(() {
                            _diamantsAffiches =
                                (_diamantsAffiches - 5).clamp(0, 999999);
                          });
                        },
                  child: const Text("-5 💎"),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onDiamondsChanged(10);
                    setState(() => _diamantsAffiches += 10);
                  },
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: const Text(
                    "+10 💎",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LaboPalette.good,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onClearDiamonds();
                    setState(() => _diamantsAffiches = 0);
                  },
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
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
            if (widget.memoire != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _ouvrirSuiviDetaille,
                  icon: const Icon(Icons.bar_chart),
                  label: const Text("📊 Suivi détaillé d'Émile"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LaboPalette.encre,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _ouvrirTestExercices,
                icon: const Icon(Icons.science_outlined),
                label: const Text("🧪 Tester les exercices (sans points)"),
              ),
            ),
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
            const Divider(height: 30),
            const Text(
              "✨ Création de leçons par photo (Gemini)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: LaboPalette.muted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              masquerCleGemini(_cleGemini),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _configurerCleGemini,
                icon: const Icon(Icons.key),
                label: const Text("Configurer la clé Gemini gratuite"),
              ),
            ),
            const Divider(height: 30),
            const Text(
              "☁️ Synchronisation (Téléphone ↔ PC)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: LaboPalette.muted,
              ),
            ),
            const SizedBox(height: 6),
            ListenableBuilder(
              listenable: LaboSyncService(),
              builder: (_, _) {
                final sync = LaboSyncService();
                final enCours = sync.etat == EtatSyncLabo.synchronisation;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      sync.libelleEtat,
                      style: TextStyle(
                        fontSize: 14,
                        color: sync.etat == EtatSyncLabo.erreur
                            ? LaboPalette.rouge
                            : LaboPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (sync.estConfigure) ...[
                      OutlinedButton.icon(
                        onPressed: enCours
                            ? null
                            : () async {
                                final ok = await sync.synchroniserMaintenant();
                                if (!mounted) return;
                                _message(
                                  ok
                                      ? 'Synchronisation terminée.'
                                      : (sync.erreur ??
                                            'La synchronisation a échoué.'),
                                  erreur: !ok,
                                );
                              },
                        icon: const Icon(Icons.sync),
                        label: Text(
                          enCours
                              ? 'Synchronisation en cours…'
                              : '🔄 Synchroniser maintenant',
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (Theme.of(context).platform == TargetPlatform.windows) ...[
                        OutlinedButton.icon(
                          onPressed: enCours || _envoiUsbEnCours
                              ? null
                              : () async {
                                  setState(() => _envoiUsbEnCours = true);
                                  final res =
                                      await sync.envoyerSessionAuTelephoneUsb();
                                  if (!mounted) return;
                                  setState(() => _envoiUsbEnCours = false);
                                  _message(res.message, erreur: !res.ok);
                                },
                          icon: const Icon(Icons.phone_android),
                          label: Text(
                            _envoiUsbEnCours
                                ? 'Envoi vers le téléphone…'
                                : '📱 Transférer ce compte au téléphone (USB)',
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      OutlinedButton.icon(
                        onPressed: enCours
                            ? null
                            : () async {
                                final code = sync.exporterCodeConnexionIpad();
                                if (code == null) return;
                                await Clipboard.setData(
                                  ClipboardData(text: code),
                                );
                                if (!mounted) return;
                                _message(
                                  'Code copié ! Colle-le une seule fois dans le Labo sur iPad.',
                                );
                              },
                        icon: const Icon(Icons.copy_all),
                        label: const Text(
                          '📋 Copier le code de connexion (iPad / Web)',
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    OutlinedButton.icon(
                      onPressed: enCours
                          ? null
                          : () async {
                              final modifie = await ouvrirDialogueSyncFirebase(
                                context,
                              );
                              if (!modifie || !mounted) return;
                              _message(
                                sync.estConfigure
                                    ? 'Synchronisation Firebase activée.'
                                    : 'Compte Firebase déconnecté.',
                              );
                            },
                      icon: const Icon(Icons.cloud_outlined),
                      label: Text(
                        sync.estConfigure
                            ? '⚙️ Gérer le compte Firebase'
                            : '☁️ Configurer le compte Firebase',
                      ),
                    ),
                  ],
                );
              },
            ),
            const Divider(height: 30),
            const Text(
              "💾 Sauvegarde de la progression",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: LaboPalette.muted,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copierSauvegarde,
                    icon: const Icon(Icons.copy),
                    label: const Text("Copier la sauvegarde"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _restaurerSauvegarde,
                    icon: const Icon(Icons.restore),
                    label: const Text("Restaurer une sauvegarde"),
                  ),
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
            const Center(
              child: Text(
                "Labo d'Émile v$kVersionAppli",
                style: TextStyle(color: LaboPalette.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../logic/parcours_logic.dart';
import '../logic/seance_logic.dart';
import '../models/lesson_model.dart';
import '../logic/memoire.dart';
import '../services/labo_sync_service.dart';
import '../services/memoire_service.dart';
import '../services/questions_masquees_service.dart';
import '../services/sound_service.dart';
import 'pin_gate.dart';

class ExerciseView extends StatefulWidget {
  final LessonModel lesson;
  final VoidCallback onSuccess;
  final VoidCallback onFailure;
  final VoidCallback onPerfectScore;

  /// Mode « Révision du jour » : la leçon ne contient que l'exercice à
  /// réviser ; pas de séance ni d'étoile, et cette fonction est appelée
  /// quand on touche « SUIVANT ».
  final VoidCallback? surFin;

  /// Mode « parcours » : appelée une seule fois à la fin de la séance, avec
  /// le résultat ; la vue n'affiche alors pas son propre écran de fin.
  final void Function(ResultatEtape)? surResultat;

  const ExerciseView({
    super.key,
    required this.lesson,
    required this.onSuccess,
    required this.onFailure,
    required this.onPerfectScore,
    this.surFin,
    this.surResultat,
  });

  @override
  State<ExerciseView> createState() => _ExerciseViewState();
}

class _ExerciseViewState extends State<ExerciseView> {
  int _currentIndex = 0;
  bool _isSubmitted = false; // l'exercice est terminé (juste ou réponse montrée)
  bool _isCorrect = false;
  int _attempt = 1; // 1er ou 2e essai
  bool _showHint = false; // indice affiché (après une 1re erreur)
  int _failedFinal = 0; // exercices finis « réponse montrée » dans la séance
  int _nbPremier = 0; // résultats de la séance, pour le parcours
  int _nbDeuxieme = 0;
  final List<String> _ratees = [];
  bool _resultatEnvoye = false;

  // ── Séance : indices (dans la leçon) des exercices tirés ──────────────────
  List<int> _sessionIndices = [];
  Set<int> _vus = {};
  bool _loading = true;
  bool _hasRemaining = false;

  String get _prefsKey => 'seance_vus_${widget.lesson.titre}';

  // ── Options QCM mélangées pour la question courante ───────────────────────
  List<String> _shuffledOptions = [];

  // ── Trous numériques ──────────────────────────────────────────────────────
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];

  // ── QCM ───────────────────────────────────────────────────────────────────
  List<String> _selectedOptions = [];
  int _activeSlot = 0;

  // ── Ordre (indices sélectionnés dans _shuffledOptions) ────────────────────
  final List<int> _ordreChoisisIndices = [];

  static const String _hole = '[?]';

  // ── Exercice courant (via les indices de la séance) ───────────────────────
  ExerciseModel get _currentExercise =>
      widget.lesson.exercices[_sessionIndices[_currentIndex]];

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  @override
  void didUpdateWidget(covariant ExerciseView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lesson != widget.lesson) {
      _startSession();
    }
  }

  @override
  void dispose() {
    _disposeInputs();
    super.dispose();
  }

  /// Tire une nouvelle séance de 10 exercices (en tenant compte de ceux déjà
  /// vus lors des séances précédentes de cette leçon).
  Future<void> _startSession() async {
    final lesson = widget.lesson;
    if (widget.surFin != null) {
      // Révision du jour : on ne touche pas aux séances (seance_vus_*).
      // (Appelé depuis initState ou didUpdateWidget : pas de setState.)
      _sessionIndices = List<int>.generate(lesson.exercices.length, (i) => i);
      _vus = {};
      _currentIndex = 0;
      _failedFinal = 0;
      _nbPremier = 0;
      _nbDeuxieme = 0;
      _ratees.clear();
      _resultatEnvoye = false;
      _hasRemaining = false;
      _initCurrentExercise();
      _loading = false;
      return;
    }
    if (mounted && !_loading) setState(() => _loading = true);
    Set<int> vus = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      vus = (prefs.getStringList(_prefsKey) ?? [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
    } catch (_) {}
    if (!mounted || lesson != widget.lesson) return;
    final tirage = tirerSeance(lesson.exercices.length, vus);
    final indicesFiltres = tirage.indices.where((i) {
      final cle = cleQuestion(
        lesson.titre,
        TypeQuestion.exercice,
        lesson.exercices[i].question,
      );
      return !QuestionsMasqueesService().estMasquee(cle);
    }).toList();
    setState(() {
      _sessionIndices = indicesFiltres;
      _vus = tirage.vusApres;
      _currentIndex = 0;
      _failedFinal = 0;
      _nbPremier = 0;
      _nbDeuxieme = 0;
      _ratees.clear();
      _resultatEnvoye = false;
      _hasRemaining = _vus.length < lesson.exercices.length;
      _initCurrentExercise();
      _loading = false;
    });
  }

  Future<void> _saveSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsKey,
        _vus.map((i) => i.toString()).toList(),
      );
      LaboSyncService().signalerChangementLocal();
    } catch (_) {}
  }

  void _disposeInputs() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();
  }

  void _initCurrentExercise() {
    _disposeInputs();
    _isSubmitted = false;
    _isCorrect = false;
    _attempt = 1;
    _showHint = false;
    _activeSlot = 0;

    if (_sessionIndices.isEmpty || _currentIndex >= _sessionIndices.length) {
      return;
    }

    final currentEx = _currentExercise;
    final int nbTrous = currentEx.question.split(_hole).length - 1;

    // ✅ Slot virtuel pour QCM sans [?] (stocke la réponse choisie)
    final int nbSlots = (currentEx.type == ExerciseType.textQcm && nbTrous == 0)
        ? 1
        : nbTrous;
    _selectedOptions = List.filled(nbSlots, '');

    // ✅ Options mélangées aléatoirement pour chaque question QCM (sauf Vrai/Faux)
    _ordreChoisisIndices.clear();
    if (currentEx.type == ExerciseType.textQcm) {
      if (currentEx.typeExplicite == 'vraiFaux') {
        _shuffledOptions = currentEx.options.isNotEmpty
            ? List<String>.from(currentEx.options)
            : ['Vrai', 'Faux'];
      } else {
        _shuffledOptions = List<String>.from(currentEx.options)
          ..shuffle(Random());
      }
    } else if (currentEx.type == ExerciseType.ordre) {
      final base = currentEx.options.isNotEmpty
          ? currentEx.options
          : currentEx.reponsesMultiples;
      _shuffledOptions = List<String>.from(base)..shuffle(Random());
    } else {
      _shuffledOptions = [];
      final int nbChamps = nbTrous > 0 ? nbTrous : 1;
      for (int i = 0; i < nbChamps; i++) {
        _controllers.add(TextEditingController());
        _focusNodes.add(FocusNode());
      }
    }
  }

  // ── Validation trous numériques ────────────────────────────────────────────
  void _validateNumericAnswers(ExerciseModel currentEx) {
    if (_isSubmitted) return;
    FocusScope.of(context).unfocus();

    bool allGood;
    if (currentEx.reponsesMultiples.isNotEmpty) {
      allGood = true;
      for (int i = 0; i < _controllers.length; i++) {
        if (_controllers[i].text.trim() !=
            currentEx.reponsesMultiples[i].trim()) {
          allGood = false;
          break;
        }
      }
    } else if (currentEx.estSaisieMot) {
      allGood = _controllers.isNotEmpty &&
          _estReponseMotValide(_controllers[0].text, currentEx);
    } else {
      allGood =
          _controllers.isNotEmpty &&
          _controllers[0].text.trim() == currentEx.reponseAttendue.trim();
    }

    _appliquerResultat(allGood);
  }

  String _normaliserTexte(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  bool _estReponseMotValide(String saisie, ExerciseModel ex) {
    final norm = _normaliserTexte(saisie);
    if (norm.isEmpty) return false;
    if (norm == _normaliserTexte(ex.reponseAttendue)) return true;
    return ex.reponsesAcceptees.any((alt) => _normaliserTexte(alt) == norm);
  }

  // ── Sélection d'une case QCM ───────────────────────────────────────────────
  void _activateSlot(int slotIndex) {
    if (_isSubmitted) return;
    setState(() => _activeSlot = slotIndex);
  }

  // ── Remplissage d'une case QCM ────────────────────────────────────────────
  void _fillSlot(String option) {
    if (_isSubmitted) return;
    setState(() {
      _selectedOptions[_activeSlot] = option;
    });
  }

  // ── Validation QCM ────────────────────────────────────────────────────────
  void _validateQcm(ExerciseModel currentEx) {
    if (_isSubmitted) return;
    if (_selectedOptions.contains('')) return;

    bool allGood;
    if (_selectedOptions.length == 1) {
      allGood =
          _selectedOptions[0].trim().toUpperCase() ==
          currentEx.reponseAttendue.trim().toUpperCase();
    } else {
      allGood = true;
      for (int i = 0; i < _selectedOptions.length; i++) {
        final expected = i < currentEx.reponsesMultiples.length
            ? currentEx.reponsesMultiples[i].trim().toUpperCase()
            : '';
        if (_selectedOptions[i].trim().toUpperCase() != expected) {
          allGood = false;
          break;
        }
      }
    }

    _appliquerResultat(allGood);
  }

  // ── Validation Ordre ──────────────────────────────────────────────────────
  void _validateOrdre(ExerciseModel currentEx) {
    if (_isSubmitted) return;
    if (_ordreChoisisIndices.length != currentEx.reponsesMultiples.length) {
      return;
    }
    var allGood = true;
    for (int i = 0; i < currentEx.reponsesMultiples.length; i++) {
      final choisi = _shuffledOptions[_ordreChoisisIndices[i]].trim();
      final attendu = currentEx.reponsesMultiples[i].trim();
      if (choisi.toLowerCase() != attendu.toLowerCase()) {
        allGood = false;
        break;
      }
    }
    _appliquerResultat(allGood);
  }

  /// Applique le résultat d'un essai : juste, 2e essai avec indice, ou
  /// bonne réponse montrée.
  void _appliquerResultat(bool estJuste) {
    final res = resoudreEssai(estJuste: estJuste, essai: _attempt);
    // Mémoire par question : on note le résultat final (juste ou montrée).
    if (res != ResultatEssai.reessayer) {
      MemoireService().enregistrer(
        cleQuestion(
          widget.lesson.titre,
          TypeQuestion.exercice,
          _currentExercise.question,
        ),
        res == ResultatEssai.montrerReponse
            ? Resultat.rate
            : (_attempt == 1 ? Resultat.premierCoup : Resultat.deuxiemeEssai),
      );
    }
    if (res == ResultatEssai.juste) {
      if (_attempt == 1) {
        _nbPremier++;
      } else {
        _nbDeuxieme++;
      }
    } else if (res == ResultatEssai.montrerReponse) {
      _ratees.add(texteCourt(_currentExercise.question));
    }
    setState(() {
      switch (res) {
        case ResultatEssai.juste:
          _isSubmitted = true;
          _isCorrect = true;
          SoundService().playSuccess();
          SoundService().hapticSuccess();
          widget.onSuccess();
          break;
        case ResultatEssai.reessayer:
          // Indice, puis on vide les cases pour un 2e essai.
          SoundService().playError();
          SoundService().hapticError();
          widget.onFailure(); // le combo descend d'un cran
          _attempt = 2;
          _showHint = true;
          for (final c in _controllers) {
            c.clear();
          }
          _selectedOptions = List.filled(_selectedOptions.length, '');
          _activeSlot = 0;
          _ordreChoisisIndices.clear();
          break;
        case ResultatEssai.montrerReponse:
          _isSubmitted = true;
          _isCorrect = false;
          _failedFinal++;
          SoundService().playError();
          SoundService().hapticError();
          break;
      }
    });
  }

  void _nextQuestion() {
    if (widget.surFin != null) {
      widget.surFin!();
      return;
    }
    setState(() {
      _currentIndex++;
      if (_currentIndex < _sessionIndices.length) {
        _initCurrentExercise();
      } else {
        // Fin de séance : on retient les exercices vus, et l'étoile est
        // donnée si tout est juste (au besoin au 2e essai).
        _saveSeen();
        final etoile = etoileExercices(_failedFinal);
        if (etoile) {
          widget.onPerfectScore();
        }
        _envoyerResultat(etoile);
      }
    });
  }

  /// Mode parcours : remonte le résultat une seule fois, hors construction.
  void _envoyerResultat(bool etoile) {
    final cb = widget.surResultat;
    if (cb == null || _resultatEnvoye) return;
    _resultatEnvoye = true;
    final r = ResultatEtape(
      premierCoup: _nbPremier,
      deuxiemeEssai: _nbDeuxieme,
      rates: _failedFinal,
      etoile: etoile,
      aRetravailler: List.of(_ratees),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cb(r);
    });
  }

  // ── Question avec cases intégrées ─────────────────────────────────────────
  Widget _buildQuestionWithSlots(ExerciseModel currentEx) {
    final List<String> parts = currentEx.question.split(_hole);
    final bool isQcm = currentEx.type == ExerciseType.textQcm;
    final int nbTrous = parts.length - 1;
    final List<Widget> widgets = [];

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        widgets.add(
          Text(
            parts[i],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: LaboPalette.ink,
            ),
          ),
        );
      }

      // Affiche une case par [?], ou un champ unique à la suite pour une
      // question numérique sans [?] (ex. « Combien de faces possède un cube ? »).
      final bool hasSlot = isQcm
          ? i < nbTrous
          : (nbTrous > 0
              ? i < _controllers.length
              : i == 0 && _controllers.isNotEmpty);

      if (hasSlot) {
        if (isQcm) {
          final String chosen = _selectedOptions[i];
          final bool filled = chosen.isNotEmpty;
          final bool isActive = (_activeSlot == i) && !_isSubmitted;

          Color borderColor;
          Color chipColor;
          Color textColor;

          if (_isSubmitted) {
            bool slotCorrect;
            if (_selectedOptions.length == 1) {
              slotCorrect =
                  chosen.trim().toUpperCase() ==
                  currentEx.reponseAttendue.trim().toUpperCase();
            } else {
              final expected = i < currentEx.reponsesMultiples.length
                  ? currentEx.reponsesMultiples[i].trim().toUpperCase()
                  : '';
              slotCorrect = chosen.trim().toUpperCase() == expected;
            }
            chipColor = slotCorrect
                ? Colors.green.shade100
                : Colors.red.shade100;
            borderColor = slotCorrect ? LaboPalette.good : LaboPalette.rouge;
            textColor = slotCorrect
                ? Colors.green.shade800
                : Colors.red.shade800;
          } else if (isActive) {
            chipColor = Colors.blue.shade50;
            borderColor = LaboPalette.encre;
            textColor = Colors.blue.shade800;
          } else if (filled) {
            chipColor = Colors.orange.shade50;
            borderColor = Colors.orange.shade300;
            textColor = Colors.orange.shade800;
          } else {
            chipColor = Colors.grey.shade100;
            borderColor = Colors.grey.shade400;
            textColor = Colors.grey.shade400;
          }

          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4.0,
                vertical: 2.0,
              ),
              child: GestureDetector(
                onTap: () => _activateSlot(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  constraints: const BoxConstraints(minWidth: 64),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: LaboShape.button,
                    border: Border.all(
                      color: borderColor,
                      width: isActive ? 2.5 : 1.5,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    filled ? chosen : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        } else {
          final estMot = currentEx.estSaisieMot;
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: SizedBox(
                width: estMot ? 180 : 72,
                height: 46,
                child: TextField(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  enabled: !_isSubmitted,
                  keyboardType:
                      estMot ? TextInputType.text : TextInputType.number,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: i < _controllers.length - 1
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onSubmitted: (_) {
                    if (i < _focusNodes.length - 1) {
                      _focusNodes[i + 1].requestFocus();
                    } else {
                      _validateNumericAnswers(currentEx);
                    }
                  },
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: LaboPalette.encre,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: LaboShape.button,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: LaboShape.button,
                      borderSide: BorderSide(
                        color: _isSubmitted
                            ? (_isCorrect ? LaboPalette.good : LaboPalette.rouge)
                            : Colors.grey,
                        width: 2,
                      ),
                    ),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 8,
      children: widgets,
    );
  }

  Widget _infoBox(String text, Color bg, Color fg) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: fg, fontWeight: FontWeight.bold),
    ),
  );

  Future<void> _signalerQuestion() async {
    final ok = await demanderCodeParent(context);
    if (!ok || !mounted) return;
    final ex = _currentExercise;
    final cle = cleQuestion(
      widget.lesson.titre,
      TypeQuestion.exercice,
      ex.question,
    );
    await QuestionsMasqueesService().masquer(cle);
    if (!mounted) return;
    setState(() {
      _sessionIndices.removeAt(_currentIndex);
      if (_currentIndex < _sessionIndices.length) {
        _initCurrentExercise();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Question masquée (réaffichable dans Espace Parent).'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (widget.lesson.exercices.isEmpty) {
      return const Center(child: Text("📝 Pas d'exercices."));
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentIndex >= _sessionIndices.length) {
      if (widget.surResultat != null) return const SizedBox.shrink();
      final bool etoile = etoileExercices(_failedFinal);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '🏆 Séance terminée !',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: LaboPalette.encre,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                etoile
                    ? 'Tout est juste, bravo !'
                    : 'Bien joué ! Tu as fini ta séance. '
                          'Les réponses montrées reviendront bientôt.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _startSession,
                child: Text(
                  _hasRemaining
                      ? 'Séance suivante (nouveaux exercices)'
                      : 'Refaire une séance',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentEx = _currentExercise;
    final bool isQcm = currentEx.type == ExerciseType.textQcm;
    final bool isOrdre = currentEx.type == ExerciseType.ordre;
    final int nbTrous = currentEx.question.split(_hole).length - 1;
    final bool hasVisibleSlots = isQcm && nbTrous > 0;
    final bool allSlotsFilled = !_selectedOptions.contains('');
    final bool allOrdrePlaced =
        _ordreChoisisIndices.length == currentEx.reponsesMultiples.length;
    final bool canValidate =
        isQcm ? allSlotsFilled : (isOrdre ? allOrdrePlaced : true);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Adapte les tailles selon l'espace vertical disponible
        final double availH = constraints.maxHeight;
        final bool isCompact = availH < 560;   // seuil rehaussé pour couvrir plus d'écrans
        final double btnH = isCompact ? 36.0 : 46.0;
        final double btnSpacing = isCompact ? 4.0 : 8.0;
        final double innerPad = isCompact ? 8.0 : 16.0;
        final double gap1 = isCompact ? 6.0 : 20.0;
        final double gap2 = isCompact ? 8.0 : 24.0;
        final double outerPad = isCompact ? 6.0 : 12.0;
        final double btnFontSize = isCompact ? 13.0 : 14.0;
        final double consoleFontSize = isCompact ? 11.0 : 13.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(outerPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.surFin == null)
              Text(
                'Exercice ${_currentIndex + 1} / ${_sessionIndices.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: LaboPalette.muted,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.surFin == null) SizedBox(height: outerPad * 0.67),
              Card(
                color: LaboPalette.paper,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: LaboPalette.line, width: 2),
                ),
                child: Padding(
                  padding: EdgeInsets.all(innerPad),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                          Row(
                            children: [
                              const SizedBox(width: 28),
                              Expanded(
                                child: Text(
                                  currentEx.consigne,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: consoleFontSize,
                                    color: LaboPalette.encre,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (widget.surFin == null)
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  tooltip: 'Signaler / masquer (parent)',
                                  icon: const Icon(
                                    Icons.flag_outlined,
                                    size: 16,
                                    color: LaboPalette.muted,
                                  ),
                                  onPressed: _signalerQuestion,
                                )
                              else
                                const SizedBox(width: 28),
                            ],
                          ),
                          SizedBox(height: gap1),
                          _buildQuestionWithSlots(currentEx),
                          SizedBox(height: gap2),

                          // Zone interactive Ordre
                          if (isOrdre) ...[
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(minHeight: 54),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: LaboPalette.line),
                              ),
                              child: _ordreChoisisIndices.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'Clique sur les étiquettes ci-dessous dans le bon ordre',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: LaboPalette.muted,
                                        ),
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        for (var pos = 0;
                                            pos < _ordreChoisisIndices.length;
                                            pos++)
                                          InputChip(
                                            label: Text(
                                              _shuffledOptions[
                                                  _ordreChoisisIndices[pos]],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            backgroundColor: Colors.blue.shade50,
                                            onPressed: _isSubmitted
                                                ? null
                                                : () => setState(() {
                                                      _ordreChoisisIndices
                                                          .removeAt(pos);
                                                    }),
                                          ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                for (var idx = 0;
                                    idx < _shuffledOptions.length;
                                    idx++)
                                  ActionChip(
                                    label: Text(_shuffledOptions[idx]),
                                    backgroundColor:
                                        _ordreChoisisIndices.contains(idx)
                                            ? Colors.grey.shade200
                                            : Colors.white,
                                    onPressed: _isSubmitted ||
                                            _ordreChoisisIndices.contains(idx)
                                        ? null
                                        : () => setState(() {
                                              _ordreChoisisIndices.add(idx);
                                            }),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Boutons options QCM (mélangés)
                          if (isQcm)
                            ..._shuffledOptions.map((option) {
                              final bool isSelected = _selectedOptions.any(
                                (s) =>
                                    s.trim().toUpperCase() ==
                                    option.trim().toUpperCase(),
                              );

                              Color? btnColor;
                              Color? textColor;
                              if (_isSubmitted) {
                                final bool isCorrectOption =
                                    currentEx.reponsesMultiples.isNotEmpty
                                    ? currentEx.reponsesMultiples.any(
                                        (r) =>
                                            r.trim().toUpperCase() ==
                                            option.trim().toUpperCase(),
                                      )
                                    : option.trim().toUpperCase() ==
                                          currentEx.reponseAttendue
                                              .trim()
                                              .toUpperCase();
                                final bool wasChosen = _selectedOptions.any(
                                  (s) =>
                                      s.trim().toUpperCase() ==
                                      option.trim().toUpperCase(),
                                );
                                if (isCorrectOption) {
                                  btnColor = Colors.green.shade100;
                                  textColor = Colors.green.shade900;
                                } else if (wasChosen) {
                                  btnColor = Colors.red.shade100;
                                  textColor = Colors.red.shade900;
                                }
                              } else if (isSelected) {
                                btnColor = Colors.blue.shade50;
                                textColor = Colors.blue.shade800;
                              }

                              return Padding(
                                padding: EdgeInsets.only(bottom: btnSpacing),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: btnH,
                                  child: OutlinedButton(
                                    onPressed: _isSubmitted
                                        ? null
                                        : () => _fillSlot(option),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: btnColor ?? Colors.white,
                                      side: BorderSide(
                                        color: isSelected && !_isSubmitted
                                            ? LaboPalette.encre
                                            : Colors.black12,
                                        width: isSelected && !_isSubmitted ? 2 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        fontSize: btnFontSize,
                                        fontWeight: isSelected && !_isSubmitted
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),

                          if (_showHint && !_isSubmitted)
                            _infoBox(
                              '💡 Indice : ${currentEx.astuceErreur.trim().isEmpty ? "Relis bien la question, tu as un 2e essai." : currentEx.astuceErreur}',
                              Colors.blue.shade50,
                              Colors.blue.shade900,
                            ),
                          if (_isSubmitted && _isCorrect)
                            _infoBox(
                              '${_attempt == 2 ? 'Bravo, tu as trouvé ! 🎉' : 'Bravo ! 🎉'}'
                              '${(currentEx.explication ?? '').isEmpty ? '' : '\n${currentEx.explication}'}',
                              Colors.green.shade50,
                              Colors.green.shade900,
                            ),
                          if (_isSubmitted && !_isCorrect)
                            _infoBox(
                              'La bonne réponse : ${texteBonneReponse(currentEx)}'
                              '${(currentEx.explication ?? currentEx.astuceErreur).trim().isEmpty ? "" : "\n💡 ${(currentEx.explication ?? currentEx.astuceErreur).trim()}"}',
                              Colors.amber.shade50,
                              Colors.brown.shade800,
                            ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _isSubmitted
                      ? _nextQuestion
                      : (canValidate
                            ? () => isQcm
                                  ? _validateQcm(currentEx)
                                  : (isOrdre
                                        ? _validateOrdre(currentEx)
                                        : _validateNumericAnswers(currentEx))
                            : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSubmitted
                        ? LaboPalette.encre
                        : (canValidate ? LaboPalette.good : Colors.grey.shade400),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: LaboShape.card,
                    ),
                  ),
                  child: Text(
                    _isSubmitted
                        ? 'SUIVANT ➡️'
                        : (hasVisibleSlots && !allSlotsFilled
                              ? 'REMPLIS TOUTES LES CASES 👆'
                              : '🚀 VALIDER MA RÉPONSE'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }
}

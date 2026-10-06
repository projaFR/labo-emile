import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lesson_model.dart';
import '../services/sound_service.dart';

class ExerciseView extends StatefulWidget {
  final LessonModel lesson;
  final VoidCallback onSuccess;
  final VoidCallback onFailure;
  final VoidCallback onPerfectScore;

  const ExerciseView({
    super.key,
    required this.lesson,
    required this.onSuccess,
    required this.onFailure,
    required this.onPerfectScore,
  });

  @override
  State<ExerciseView> createState() => _ExerciseViewState();
}

class _ExerciseViewState extends State<ExerciseView> {
  int _currentIndex = 0;
  bool _isSubmitted = false;
  bool _isCorrect = false;
  int _errorsInThisSeries = 0;

  // ── Ordre aléatoire des exercices ─────────────────────────────────────────
  List<int> _shuffledIndices = [];

  // ── Options QCM mélangées pour la question courante ───────────────────────
  List<String> _shuffledOptions = [];

  // ── Trous numériques ──────────────────────────────────────────────────────
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];

  // ── QCM ───────────────────────────────────────────────────────────────────
  List<String> _selectedOptions = [];
  int _activeSlot = 0;

  static const String _hole = '[?]';

  // ── Exercice courant (via indice mélangé) ─────────────────────────────────
  ExerciseModel get _currentExercise {
    final idx = _currentIndex < _shuffledIndices.length
        ? _shuffledIndices[_currentIndex]
        : _currentIndex;
    return widget.lesson.exercices[idx];
  }

  @override
  void initState() {
    super.initState();
    _shuffleExercises();
    _initCurrentExercise();
  }

  @override
  void didUpdateWidget(covariant ExerciseView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lesson != widget.lesson) {
      setState(() {
        _currentIndex = 0;
        _errorsInThisSeries = 0;
        _shuffleExercises();
        _initCurrentExercise();
      });
    }
  }

  @override
  void dispose() {
    _disposeInputs();
    super.dispose();
  }

  void _shuffleExercises() {
    _shuffledIndices = List.generate(widget.lesson.exercices.length, (i) => i)
      ..shuffle(Random());
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
    _activeSlot = 0;

    final exercises = widget.lesson.exercices;
    if (exercises.isEmpty || _currentIndex >= exercises.length) return;

    final currentEx = _currentExercise;
    final int nbTrous = currentEx.question.split(_hole).length - 1;

    // ✅ Slot virtuel pour QCM sans [?] (stocke la réponse choisie)
    final int nbSlots = (currentEx.type == ExerciseType.textQcm && nbTrous == 0)
        ? 1
        : nbTrous;
    _selectedOptions = List.filled(nbSlots, '');

    // ✅ Options mélangées aléatoirement pour chaque question QCM
    if (currentEx.type == ExerciseType.textQcm) {
      _shuffledOptions = List<String>.from(currentEx.options)
        ..shuffle(Random());
    } else {
      _shuffledOptions = [];
      for (int i = 0; i < nbTrous; i++) {
        final controller = TextEditingController();
        final focusNode = FocusNode();
        final int idx = i;
        controller.addListener(() {
          if (controller.text.isNotEmpty && idx < _focusNodes.length - 1) {
            _focusNodes[idx + 1].requestFocus();
          }
        });
        _controllers.add(controller);
        _focusNodes.add(focusNode);
      }
    }
  }

  void _resetExercise() {
    setState(() {
      _currentIndex = 0;
      _errorsInThisSeries = 0;
      _shuffleExercises();
      _initCurrentExercise();
    });
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
    } else {
      allGood =
          _controllers.isNotEmpty &&
          _controllers[0].text.trim() == currentEx.reponseAttendue.trim();
    }

    setState(() {
      _isSubmitted = true;
      _isCorrect = allGood;
      if (_isCorrect) {
        SoundService().playSuccess();
        HapticFeedback.lightImpact();
        widget.onSuccess();
      } else {
        SoundService().playError();
        HapticFeedback.heavyImpact();
        _errorsInThisSeries++;
        widget.onFailure();
      }
    });
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

    setState(() {
      _isSubmitted = true;
      _isCorrect = allGood;
      if (_isCorrect) {
        SoundService().playSuccess();
        HapticFeedback.lightImpact();
        widget.onSuccess();
      } else {
        SoundService().playError();
        HapticFeedback.heavyImpact();
        _errorsInThisSeries++;
        widget.onFailure();
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      _currentIndex++;
      if (_currentIndex < widget.lesson.exercices.length) {
        _initCurrentExercise();
      } else if (_errorsInThisSeries == 0) {
        widget.onPerfectScore();
      }
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
              color: Color(0xFF2C3E50),
            ),
          ),
        );
      }

      // N'affiche une case que pour les vrais [?] (pas le slot virtuel)
      final bool hasSlot = isQcm ? i < nbTrous : i < _controllers.length;

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
            borderColor = slotCorrect ? Colors.green : Colors.red;
            textColor = slotCorrect
                ? Colors.green.shade800
                : Colors.red.shade800;
          } else if (isActive) {
            chipColor = Colors.blue.shade50;
            borderColor = Colors.blue;
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
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: borderColor,
                      width: isActive ? 2.5 : 1.5,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.2),
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
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: SizedBox(
                width: 72,
                height: 46,
                child: TextField(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  enabled: !_isSubmitted,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _isSubmitted
                            ? (_isCorrect ? Colors.green : Colors.red)
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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (widget.lesson.exercices.isEmpty) {
      return const Center(child: Text("📝 Pas d'exercices."));
    }

    if (_currentIndex >= widget.lesson.exercices.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '🏆 Série terminée !',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _resetExercise,
              child: const Text('Recommencer'),
            ),
          ],
        ),
      );
    }

    final currentEx = _currentExercise;
    final bool isQcm = currentEx.type == ExerciseType.textQcm;
    final int nbTrous = currentEx.question.split(_hole).length - 1;
    final bool hasVisibleSlots = isQcm && nbTrous > 0;
    final bool allSlotsFilled = !_selectedOptions.contains('');
    final bool canValidate = isQcm ? allSlotsFilled : true;

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
              Text(
                'Exercice ${_currentIndex + 1} / ${widget.lesson.exercices.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: outerPad * 0.67),
              Card(
                color: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
                ),
                child: Padding(
                  padding: EdgeInsets.all(innerPad),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                          Text(
                            currentEx.consigne,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: consoleFontSize,
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: gap1),
                          _buildQuestionWithSlots(currentEx),
                          SizedBox(height: gap2),

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
                                            ? Colors.blue
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

                          if (_isSubmitted)
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _isCorrect
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _isCorrect
                                    ? 'Bravo ! 🎉'
                                    : 'Aide : ${currentEx.astuceErreur}',
                                style: TextStyle(
                                  color: _isCorrect
                                      ? Colors.green.shade900
                                      : Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                                  : _validateNumericAnswers(currentEx)
                            : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSubmitted
                        ? Colors.blue
                        : (canValidate ? Colors.green : Colors.grey.shade400),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

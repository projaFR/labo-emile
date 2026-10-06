import 'dart:convert';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sound_service.dart';
import '../models/lesson_model.dart';
import '../data/database.dart';
import 'flashcards_view.dart';
import 'exercise_view.dart';
import 'parent_view.dart';
import 'quiz_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _selectedSubject = 'Mathématiques';
  late LessonModel _selectedLesson;
  int _totalDiamonds = 0;
  int _currentCombo = 0;

  late ConfettiController _confettiController;
  final Map<String, List<bool>> _lessonsRewards = {};

  // Copie indépendante de la base initiale — évite de polluer InitialDatabase.data
  // (qui est static final et partagé) avec les leçons custom.
  final Map<String, List<LessonModel>> _database = {
    for (final e in InitialDatabase.data.entries)
      e.key: List<LessonModel>.from(e.value),
  };

  // Titres des leçons initiales, capturés une fois pour toujours au démarrage.
  // Utilisé par _saveCustomLessons pour ne sauvegarder QUE les leçons ajoutées.
  late final Set<String> _initialTitles = {
    for (final lessons in InitialDatabase.data.values)
      for (final l in lessons) l.titre,
  };

  // ── 100 niveaux RPG ──────────────────────────────────────────────────────
  static const List<String> _rankTitles = [
    "🥚 Œuf Mystérieux",
    "🐣 Poussin Curieux",
    "🗡️ Recrue Courageuse",
    "🛡️ Chevalier Junior",
    "🏹 Archer Savant",
    "🔮 Mage des Formules",
    "🐉 Dompteur de Dragons",
    "⚡ Maître du Tonnerre",
    "💫 Élu des Étoiles",
    "👑 Dieu du Savoir",
  ];

  static int _thresholdForLevel(int level) {
    if (level <= 1) return 0;
    int total = 0;
    for (int i = 1; i < level; i++) {
      total += i * 8;
    }
    return total;
  }

  int get _currentLevel {
    int level = 1;
    for (int i = 2; i <= 100; i++) {
      if (_totalDiamonds >= _thresholdForLevel(i)) {
        level = i;
      } else {
        break;
      }
    }
    return level;
  }

  String get _rankTitle {
    final int rankIndex = ((_currentLevel - 1) ~/ 10).clamp(
      0,
      _rankTitles.length - 1,
    );
    return _rankTitles[rankIndex];
  }

  String _getBadgeName() => "Nv.$_currentLevel - $_rankTitle";

  String _getBadgeForDiamonds(int diamonds) {
    int level = 1;
    for (int i = 2; i <= 100; i++) {
      if (diamonds >= _thresholdForLevel(i)) {
        level = i;
      } else {
        break;
      }
    }
    final int rankIndex = ((level - 1) ~/ 10).clamp(0, _rankTitles.length - 1);
    return "Nv.$level - ${_rankTitles[rankIndex]}";
  }

  // Returns [threshold, label] or null if max level
  List<dynamic>? get _nextLevel {
    final int level = _currentLevel;
    if (level >= 100) return null;
    final int nextThreshold = _thresholdForLevel(level + 1);
    final int nextRankIndex = (level ~/ 10).clamp(0, _rankTitles.length - 1);
    return [nextThreshold, "Nv.${level + 1} - ${_rankTitles[nextRankIndex]}"];
  }

  double get _levelProgress {
    final int level = _currentLevel;
    if (level >= 100) return 1.0;
    final int current = _thresholdForLevel(level);
    final int next = _thresholdForLevel(level + 1);
    return ((_totalDiamonds - current) / (next - current)).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _selectedLesson = _database[_selectedSubject]!.first;
    _loadProgress();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    SoundService().dispose();
    super.dispose();
  }

  void _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();

    // Recharger les leçons personnalisées sauvegardées
    final String? customJson = prefs.getString('custom_lessons');
    if (customJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(customJson);
        decoded.forEach((matiere, lessonsJson) {
          final List<LessonModel> lessons = (lessonsJson as List)
              .map((l) => LessonModel.fromJson(l as Map<String, dynamic>))
              .toList();
          if (!_database.containsKey(matiere)) {
            _database[matiere] = [];
          }
          for (final lesson in lessons) {
            // Éviter les doublons avec les leçons initiales
            final alreadyExists = _database[matiere]!
                .any((l) => l.titre == lesson.titre);
            if (!alreadyExists) {
              _database[matiere]!.add(lesson);
            }
          }
        });
      } catch (_) {
        // JSON corrompu → on ignore, les leçons de base restent
      }
    }

    setState(() {
      _totalDiamonds = prefs.getInt('emile_diamonds') ?? 0;
      _database.forEach((matiere, lessons) {
        for (var l in lessons) {
          bool? star1 = prefs.getBool('${l.titre}_star_astuces');
          bool? star2 = prefs.getBool('${l.titre}_star_train');
          bool? star3 = prefs.getBool('${l.titre}_star_quiz');
          _lessonsRewards[l.titre] = [
            star1 ?? false,
            star2 ?? false,
            star3 ?? false,
          ];
        }
      });
    });
  }

  Future<void> _saveCustomLessons() async {
    final prefs = await SharedPreferences.getInstance();
    // On ne sauvegarde que les leçons absentes de la base initiale
    final Map<String, List<Map<String, dynamic>>> toSave = {};
    _database.forEach((matiere, lessons) {
      final custom = lessons
          .where((l) => !_initialTitles.contains(l.titre))
          .map((l) => l.toJson())
          .toList();
      if (custom.isNotEmpty) toSave[matiere] = custom;
    });
    await prefs.setString('custom_lessons', jsonEncode(toSave));
  }

  void _unlockLessonStar(String lessonTitle, int starIndex) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      if (_lessonsRewards[lessonTitle] == null) {
        _lessonsRewards[lessonTitle] = [false, false, false];
      }
      if (!_lessonsRewards[lessonTitle]![starIndex]) {
        _lessonsRewards[lessonTitle]![starIndex] = true;
        _totalDiamonds += 5;
        prefs.setBool('${lessonTitle}_star_${_getStarKey(starIndex)}', true);
        prefs.setInt('emile_diamonds', _totalDiamonds);
        SoundService().playStar();
        _confettiController.play();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⭐ Étoile débloquée pour « $lessonTitle » ! (+5 💎)"),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  String _getStarKey(int index) {
    if (index == 0) return "astuces";
    if (index == 1) return "train";
    return "quiz";
  }

  void _handleSuccess(int gain) {
    final String badgeBefore = _getBadgeForDiamonds(_totalDiamonds);
    setState(() {
      if (gain == 1) {
        _currentCombo++;
        final int finalGain = (_currentCombo >= 5) ? 3 : 1;
        _totalDiamonds += finalGain;
      } else {
        _totalDiamonds += gain;
      }
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setInt('emile_diamonds', _totalDiamonds),
      );
    });
    final String badgeAfter = _getBadgeForDiamonds(_totalDiamonds);
    if (badgeAfter != badgeBefore) {
      _celebrateLevelUp(badgeAfter);
    }
  }

  void _handleFailure() {
    setState(() => _currentCombo = 0);
  }

  void _celebrateLevelUp(String newBadge) {
    SoundService().playPerfect();
    _confettiController.play();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFF1A237E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🎉", style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              "Nouveau niveau !",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              newBadge,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Super ! 🚀",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSubjectChanged(String newSubject) {
    setState(() {
      _selectedSubject = newSubject;
      _selectedLesson = _database[_selectedSubject]!.first;
    });
  }

  void _checkParentAccess() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedPin = prefs.getString('parent_pin');
    if (savedPin == null) {
      _showSetupPinDialog(prefs);
    } else {
      _showVerifyPinDialog();
    }
  }

  void _showSetupPinDialog(SharedPreferences prefs) {
    final TextEditingController pinSetupController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("🆕 Code PIN Parent"),
        content: TextField(
          controller: pinSetupController,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            hintText: "••••",
            counterText: "",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final pin = pinSetupController.text.trim();
              if (pin.length == 4 && int.tryParse(pin) != null) {
                await prefs.setString('parent_pin', pin);
                if (context.mounted) {
                  Navigator.pop(context);
                  _openParentSettings();
                }
              }
            },
            child: const Text("CRÉER"),
          ),
        ],
      ),
    );
  }

  void _showVerifyPinDialog() {
    final TextEditingController pinVerifyController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("🔒 Accès Parent"),
        content: TextField(
          controller: pinVerifyController,
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
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final actualPin = prefs.getString('parent_pin') ?? "1234";
              if (pinVerifyController.text == actualPin) {
                if (context.mounted) {
                  Navigator.pop(context);
                  _openParentSettings();
                }
              } else {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("❌ Code PIN incorrect !"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text("VALIDER"),
          ),
        ],
      ),
    );
  }

  void _openParentSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ParentView(
        currentDiamonds: _totalDiamonds,
        currentLessonTitle: _selectedLesson.titre,
        onDiamondsChanged: (amount) {
          setState(() {
            _totalDiamonds += amount;
            SharedPreferences.getInstance().then(
              (prefs) => prefs.setInt('emile_diamonds', _totalDiamonds),
            );
          });
        },
        onClearDiamonds: () {
          setState(() {
            _totalDiamonds = 0;
            _currentCombo = 0;
            _lessonsRewards.clear();
            SharedPreferences.getInstance().then((prefs) => prefs.clear());
          });
        },
        onLessonImported: (matiere, newLesson) {
          setState(() {
            if (!_database.containsKey(matiere)) _database[matiere] = [];
            _database[matiere]!.add(newLesson);
            _selectedSubject = matiere;
            _selectedLesson = newLesson;
            _lessonsRewards[newLesson.titre] = [false, false, false];
          });
          _saveCustomLessons();
        },
        onDeleteCurrentLesson: () {
          Navigator.pop(context);
          setState(() {
            final List<LessonModel>? lessons = _database[_selectedSubject];
            if (lessons == null) return;
            lessons.removeWhere((l) => l.titre == _selectedLesson.titre);
            _lessonsRewards.remove(_selectedLesson.titre);
            if (lessons.isEmpty) {
              _database.remove(_selectedSubject);
              if (_database.isNotEmpty) {
                _selectedSubject = _database.keys.first;
                _selectedLesson = _database[_selectedSubject]!.first;
              } else {
                _database.addAll(InitialDatabase.data);
                _selectedSubject = _database.keys.first;
                _selectedLesson = _database[_selectedSubject]!.first;
              }
            } else {
              _selectedLesson = lessons.first;
            }
          });
          _saveCustomLessons();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<LessonModel> availableLessons =
        _database[_selectedSubject] ?? [];
    final List<bool> currentStars =
        _lessonsRewards[_selectedLesson.titre] ?? [false, false, false];
    final bool isLessonPerfect = currentStars.every((s) => s);
    final List<dynamic>? nextLevel = _nextLevel;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getBadgeName(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            const Text(
              'v1.3.0',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _checkParentAccess,
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. BARRE DE PROGRESSION GLOBALE
              Container(
                color: Colors.blue.shade50,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text("💎", style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              "$_totalDiamonds",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _currentCombo >= 5
                                ? Colors.orange
                                : Colors.blue.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _currentCombo >= 5
                                ? "🔥 COMBO x3 : $_currentCombo"
                                : "🔥 Combo : $_currentCombo",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _levelProgress,
                        minHeight: 5,
                        backgroundColor: Colors.blue.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          nextLevel == null
                              ? Colors.amber
                              : Colors.blue.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nextLevel == null
                          ? "🏆 Niveau maximum atteint !"
                          : "Prochain : ${nextLevel[1]} à ${nextLevel[0]} 💎",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. ETOILES DE LA LECON
              Container(
                height: 36,
                color: Colors.orange.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isLessonPerfect
                          ? "👑 Leçon Maîtrisée !"
                          : "✨ Étoiles de la leçon :",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          currentStars[0] ? "🃏⭐" : "🃏☆",
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          currentStars[1] ? "🎯⭐" : "🎯☆",
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          currentStars[2] ? "⏱️⭐" : "⏱️☆",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. SELECTION MATIERE / LECON
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 4.0,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "🎓 Matière :",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        DropdownButton<String>(
                          value: _selectedSubject,
                          icon: const Icon(
                            Icons.school,
                            color: Colors.blue,
                            size: 20,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          onChanged: (val) => _onSubjectChanged(val!),
                          items: _database.keys.map<DropdownMenuItem<String>>((
                            String subject,
                          ) {
                            return DropdownMenuItem<String>(
                              value: subject,
                              child: Text(subject),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "📝 Leçon :",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        DropdownButton<LessonModel>(
                          value: _selectedLesson,
                          icon: const Icon(
                            Icons.arrow_right,
                            color: Colors.orange,
                            size: 20,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                          onChanged: (val) =>
                              setState(() => _selectedLesson = val!),
                          items: availableLessons
                              .map<DropdownMenuItem<LessonModel>>((
                                LessonModel lesson,
                              ) {
                                bool isPerfect =
                                    _lessonsRewards[lesson.titre]?.every(
                                      (b) => b,
                                    ) ??
                                    false;
                                return DropdownMenuItem<LessonModel>(
                                  value: lesson,
                                  child: Text(
                                    isPerfect
                                        ? "👑 ${lesson.titre}"
                                        : lesson.titre,
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 4. ZONE DE JEU
              Expanded(child: _buildCurrentScreenContent()),
            ],
          ),

          // CONFETTIS
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            gravity: 0.2,
            emissionFrequency: 0.05,
            colors: const [
              Colors.blue,
              Colors.orange,
              Colors.green,
              Colors.yellow,
              Colors.purple,
              Colors.red,
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue[700],
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.style, size: 22),
            label: 'Astuces',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center, size: 22),
            label: 'Entraînement',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer, size: 22),
            label: 'Défi Chrono',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreenContent() {
    switch (_currentIndex) {
      case 0:
        return FlashcardsView(
          lesson: _selectedLesson,
          onDiamondEarned: () => _handleSuccess(1),
          onLessonCompleted: () => _unlockLessonStar(_selectedLesson.titre, 0),
        );
      case 1:
        return ExerciseView(
          lesson: _selectedLesson,
          onSuccess: () => _handleSuccess(1),
          onFailure: _handleFailure,
          onPerfectScore: () => _unlockLessonStar(_selectedLesson.titre, 1),
        );
      case 2:
        return QuizView(
          lesson: _selectedLesson,
          onSuccess: (gain) => _handleSuccess(gain),
          onFailure: _handleFailure,
          onPerfectQuiz: () => _unlockLessonStar(_selectedLesson.titre, 2),
        );
      default:
        return const Center(child: Text("Erreur"));
    }
  }
}

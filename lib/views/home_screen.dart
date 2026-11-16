import 'dart:convert';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database.dart';
import '../logic/accueil_logic.dart';
import '../logic/memoire.dart';
import '../logic/parcours_logic.dart';
import '../logic/seance_logic.dart';
import '../logic/trophees_logic.dart';
import '../models/lesson_model.dart';
import '../services/memoire_service.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../widgets/confetti_couche.dart';
import '../widgets/route_rapide.dart';
import 'aujourdhui_view.dart';
import 'import_lecon_view.dart';
import 'lecon_hub_screen.dart';
import 'lecons_view.dart';
import 'parcours_screen.dart';
import 'parent_view.dart';
import 'pin_gate.dart';
import 'revision_view.dart';
import 'trophees_view.dart';

/// Conteneur de navigation : Aujourd'hui / Leçons / Trophées.
/// Garde l'état commun (leçons, étoiles, diamants, combo).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Évitent d'ouvrir deux pages si l'enfant tape deux fois très vite.
  bool _navEnCours = false;
  bool _navParcours = false;
  int _currentIndex = 0;
  String? _matiereFiltre; // null = « Toutes »
  String? _derniereImportee;
  // Diamants : un ValueNotifier laisse le parcours compter ceux gagnés.
  final ValueNotifier<int> _diamantsNotif = ValueNotifier<int>(0);
  int get _totalDiamonds => _diamantsNotif.value;
  set _totalDiamonds(int v) => _diamantsNotif.value = v;
  int _currentCombo = 0;

  late ConfettiController _confettiController;
  final Map<String, List<bool>> _lessonsRewards = {};

  // Copie indépendante de la base initiale — évite de polluer InitialDatabase.data
  // (qui est static final et partagé) avec les leçons custom.
  final Map<String, List<LessonModel>> _database = {
    for (final e in InitialDatabase.data.entries)
      e.key: List<LessonModel>.from(e.value),
  };

  // Titres des leçons initiales, capturés une fois pour toutes au démarrage.
  // Utilisé par _saveCustomLessons pour ne sauvegarder QUE les leçons ajoutées.
  late final Set<String> _initialTitles = {
    for (final lessons in InitialDatabase.data.values)
      for (final l in lessons) l.titre,
  };

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _loadProgress();
    MemoireService().addListener(_surMemoire);
    MemoireService().charger();
  }

  void _surMemoire() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    MemoireService().removeListener(_surMemoire);
    _confettiController.dispose();
    _diamantsNotif.dispose();
    SoundService().dispose();
    super.dispose();
  }

  // ── Données ──────────────────────────────────────────────────────────────
  List<LeconRef> get _toutes => aplatir(_database);

  // Gardé en cache : recalculé seulement quand les leçons changent
  // (chargement, import, suppression), pas à chaque reconstruction.
  List<RefQuestion>? _cacheQuestions;
  List<RefQuestion> get _toutesQuestions => _cacheQuestions ??= [
    for (final lessons in _database.values)
      for (final l in lessons) ...questionsDeLecon(l),
  ];

  Memoire get _memoire => MemoireService().memoire;

  List<bool> _etoilesDe(String titre) =>
      _lessonsRewards[titre] ?? [false, false, false];

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
            final alreadyExists = _database[matiere]!.any(
              (l) => l.titre == lesson.titre,
            );
            if (!alreadyExists) {
              _database[matiere]!.add(lesson);
            }
          }
        });
      } catch (_) {
        // JSON corrompu → on ignore, les leçons de base restent
      }
    }

    if (!mounted) return;
    setState(() {
      _cacheQuestions = null;
      _derniereImportee = prefs.getString('derniere_lecon_importee');
      _totalDiamonds = prefs.getInt('emile_diamonds') ?? 0;
      _database.forEach((matiere, lessons) {
        for (var l in lessons) {
          _lessonsRewards[l.titre] = [
            prefs.getBool('${l.titre}_star_astuces') ?? false,
            prefs.getBool('${l.titre}_star_train') ?? false,
            prefs.getBool('${l.titre}_star_quiz') ?? false,
          ];
        }
      });
    });
  }

  /// Après une restauration : repart des leçons de base et relit tout.
  Future<void> _rechargerApresRestauration() async {
    _database
      ..clear()
      ..addAll({
        for (final e in InitialDatabase.data.entries)
          e.key: List<LessonModel>.from(e.value),
      });
    _lessonsRewards.clear();
    _currentCombo = 0;
    _matiereFiltre = null;
    await SettingsService().load();
    await MemoireService().charger(forcer: true);
    _loadProgress();
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
    final String encoded = jsonEncode(toSave);
    await prefs.setString('custom_lessons', encoded);
    // Vérification immédiate : relire pour s'assurer que c'est bien persisté
    final String? verify = prefs.getString('custom_lessons');
    if (verify != encoded && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Sauvegarde impossible sur ce navigateur.'),
          backgroundColor: LaboPalette.rouge,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // ── Récompenses (inchangées) ─────────────────────────────────────────────
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
            backgroundColor: LaboPalette.warn,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  /// Paquet de cartes terminé : un diamant fixe, une seule fois par leçon et
  /// par jour (rejouer le même paquet ne rapporte rien de plus).
  Future<void> _awardDeckDiamond(String lessonTitle) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    final key = 'cartes_diamant_$lessonTitle';
    if (prefs.getString(key) == today) return;
    await prefs.setString(key, today);
    if (!mounted) return;
    _handleSuccess(1, combo: false);
  }

  String _getStarKey(int index) {
    if (index == 0) return "astuces";
    if (index == 1) return "train";
    return "quiz";
  }

  void _handleSuccess(int gain, {bool combo = true}) {
    final String badgeBefore = badgePour(_totalDiamonds);
    setState(() {
      if (gain == 1 && combo) {
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
    final String badgeAfter = badgePour(_totalDiamonds);
    if (badgeAfter != badgeBefore) {
      _celebrateLevelUp(badgeAfter);
    }
  }

  void _handleFailure() {
    // Une erreur fait redescendre le combo d'un cran (au lieu de zéro).
    setState(() => _currentCombo = comboApresErreur(_currentCombo));
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
        backgroundColor: LaboPalette.nuit,
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
                color: LaboPalette.or,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: LaboPalette.or,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: LaboShape.card),
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

  // ── Révision ─────────────────────────────────────────────────────────────
  /// Récompense fixe, une seule fois par jour (pas de diamant par question).
  Future<int> _recompenseRevision() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _memoire.aujourdhui;
    if (prefs.getString('revision_diamants_jour') == today) return 0;
    await prefs.setString('revision_diamants_jour', today);
    if (!mounted) return 0;
    _handleSuccess(kDiamantsRevision, combo: false);
    return kDiamantsRevision;
  }

  void _ouvrirRevision() {
    Navigator.of(context).push(
      RouteRapide(
        builder: (_) => RevisionView(
          questions: _memoire.dues(_toutesQuestions),
          onTerminee: _recompenseRevision,
        ),
      ),
    );
  }

  /// « Réviser quand même » : les 12 questions les plus faibles, sans diamants.
  void _ouvrirRevisionLibre() {
    Navigator.of(context).push(
      RouteRapide(
        builder: (_) => RevisionView(
          questions: _memoire.plusFaibles(_toutesQuestions),
          onTerminee: () async => 0,
          libre: true,
        ),
      ),
    );
  }

  // ── Leçons ───────────────────────────────────────────────────────────────
  LeconRef? get _leconDuSoir => choisirLeconDuSoir(
    _toutes,
    _initialTitles,
    derniereImportee: _derniereImportee,
  );

  /// Page d'une leçon (depuis « Leçons »).
  void _ouvrirHub(LeconRef r) {
    if (_navEnCours) return; // un 2e appui rapide n'ouvre pas deux pages
    _navEnCours = true;
    Navigator.of(context)
        .push(
          RouteRapide(
            builder: (_) => LeconHubScreen(
              lecon: r,
              etoiles: () => _etoilesDe(r.lecon.titre),
              maitrise: () => _memoire.maitrise(questionsDeLecon(r.lecon)),
              nbARevoir: () => nbARevoirLecon(_memoire, r.lecon),
              lancer: (etapes, {required complet}) =>
                  _lancerParcours(r, etapes, complet: complet),
            ),
          ),
        )
        .then((_) {
          _navEnCours = false;
          if (mounted) setState(() {});
        });
  }

  /// Lance un parcours guidé (leçon complète ou étape isolée).
  Future<void> _lancerParcours(
    LeconRef r,
    List<int> etapes, {
    required bool complet,
    int depart = 0,
  }) {
    if (etapes.isEmpty) return Future.value();
    if (_navParcours) return Future.value();
    _navParcours = true;
    return Navigator.of(context)
        .push(
          RouteRapide(
            builder: (_) => ParcoursScreen(
              lesson: r.lecon,
              etapes: etapes,
              depart: depart,
              complet: complet,
              confetti: _confettiController,
              etoiles: () => _etoilesDe(r.lecon.titre),
              diamants: _diamantsNotif,
              onDiamondEarned: () => _awardDeckDiamond(r.lecon.titre),
              onEtoile: (i) => _unlockLessonStar(r.lecon.titre, i),
              onSuccess: _handleSuccess,
              onFailure: _handleFailure,
              onRetourAccueil: () {
                if (mounted) setState(() => _currentIndex = 0);
              },
            ),
          ),
        )
        .then((_) {
          _navParcours = false;
          if (mounted) setState(() {});
        });
  }

  void _continuerLeconDuSoir() {
    final r = _leconDuSoir;
    if (r == null) return;
    final etapes = etapesDisponibles(r.lecon);
    _lancerParcours(
      r,
      etapes,
      complet: true,
      depart: departParcours(etapes, _etoilesDe(r.lecon.titre)),
    );
  }

  /// Ajouter une leçon : code parent d'abord, puis collage du JSON.
  Future<void> _ajouterLecon() async {
    final ok = await demanderCodeParent(context);
    if (!ok || !mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ImportLeconView(onLessonImported: _surImport),
    );
  }

  void _surImport(String matiere, LessonModel newLesson) {
    setState(() {
      _cacheQuestions = null;
      if (!_database.containsKey(matiere)) _database[matiere] = [];
      _database[matiere]!.add(newLesson);
      _derniereImportee = newLesson.titre;
      _lessonsRewards[newLesson.titre] = [false, false, false];
    });
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('derniere_lecon_importee', newLesson.titre),
    );
    _saveCustomLessons().then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Leçon « ${newLesson.titre} » sauvegardée !'),
            backgroundColor: LaboPalette.good,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _supprimerLecon(String titre) {
    Navigator.pop(context); // ferme l'Espace Parent
    setState(() {
      _cacheQuestions = null;
      for (final m in _database.keys.toList()) {
        _database[m]!.removeWhere((l) => l.titre == titre);
        if (_database[m]!.isEmpty) _database.remove(m);
      }
      _lessonsRewards.remove(titre);
      if (_database.isEmpty) {
        // Réinitialiser avec une copie indépendante (pas une référence partagée)
        for (final e in InitialDatabase.data.entries) {
          _database[e.key] = List<LessonModel>.from(e.value);
        }
      }
      if (_matiereFiltre != null && !_database.containsKey(_matiereFiltre)) {
        _matiereFiltre = null;
      }
    });
    _saveCustomLessons();
  }

  // ── Espace Parent ────────────────────────────────────────────────────────
  Future<void> _ouvrirParent() async {
    final ok = await demanderCodeParent(context);
    if (!ok || !mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ParentView(
        currentDiamonds: _totalDiamonds,
        infoMemoire: () {
          final refs = _toutesQuestions;
          return "${_memoire.nombreSuiviesParmi(refs)} questions suivies, "
              "${_memoire.nombreDues(refs)} à revoir aujourd'hui";
        },
        onResetMemoire: () => MemoireService().reinitialiser(),
        onRestauree: _rechargerApresRestauration,
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
            // Ne PAS faire prefs.clear() — ça effacerait aussi les leçons custom !
            SharedPreferences.getInstance().then((prefs) {
              prefs.setInt('emile_diamonds', 0);
              // Supprimer toutes les étoiles sans toucher à custom_lessons
              _database.forEach((_, lessons) {
                for (final l in lessons) {
                  prefs.remove('${l.titre}_star_astuces');
                  prefs.remove('${l.titre}_star_train');
                  prefs.remove('${l.titre}_star_quiz');
                }
              });
            });
          });
        },
        titresLecons: [for (final r in _toutes) r.lecon.titre],
        onDeleteLesson: _supprimerLecon,
      ),
    );
  }

  // ── Écran ────────────────────────────────────────────────────────────────
  Widget _page() {
    switch (_currentIndex) {
      case 0:
        final soir = _leconDuSoir;
        return AujourdhuiView(
          diamants: _totalDiamonds,
          leconDuSoir: soir,
          etoiles: soir == null ? const [false, false, false] : _etoilesDe(soir.lecon.titre),
          nbARevoir: _memoire.nombreDues(_toutesQuestions),
          nbSuivies: _memoire.nombreSuiviesParmi(_toutesQuestions),
          onContinuer: _continuerLeconDuSoir,
          onRevision: _ouvrirRevision,
          onRevisionLibre: _ouvrirRevisionLibre,
        );
      case 1:
        return LeconsView(
          toutes: _toutes,
          matiereChoisie: _matiereFiltre,
          onMatiere: (m) => setState(() => _matiereFiltre = m),
          etoilesDe: _etoilesDe,
          maitriseDe: (r) => _memoire.maitrise(questionsDeLecon(r.lecon)),
          nbARevoirDe: (r) => nbARevoirLecon(_memoire, r.lecon),
          onOuvrir: _ouvrirHub,
          onAjouter: _ajouterLecon,
          onParent: _ouvrirParent,
        );
      default:
        final toutes = _toutes;
        return TropheesView(
          stats: calculerStats(
            diamants: _totalDiamonds,
            combo: _currentCombo,
            etoilesParLecon: [
              for (final r in toutes) _etoilesDe(r.lecon.titre),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LaboPalette.paper,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _page(),
              ),
            ),
            ConfettiCouche(controller: _confettiController),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'Aujourd\'hui'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Leçons'),
          NavigationDestination(
            icon: Icon(Icons.emoji_events),
            label: 'Trophées',
          ),
        ],
      ),
    );
  }
}

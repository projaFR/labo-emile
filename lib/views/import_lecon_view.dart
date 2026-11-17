import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/lecon_json_logic.dart';
import '../logic/trophees_logic.dart';
import '../models/lesson_model.dart';
import '../services/choisir_photo.dart';
import '../services/gemini_key_store.dart';
import '../services/gemini_lecon_service.dart';
import '../services/ouvrir_lien.dart';
import '../theme.dart';
import '../widgets/badge_rond.dart';
import '../widgets/dialogue_cle_gemini.dart';

/// Import d'une leçon : création directe depuis une photo (Gemini sur Android
/// et Windows) ou collage manuel d'un code JSON.
class ImportLeconView extends StatefulWidget {
  final void Function(String matiere, LessonModel lecon) onLessonImported;

  const ImportLeconView({super.key, required this.onLessonImported});

  @override
  State<ImportLeconView> createState() => _ImportLeconViewState();
}

class _ImportLeconViewState extends State<ImportLeconView> {
  final _jsonController = TextEditingController();
  final _precisionController = TextEditingController();

  final List<PhotoLecon> _photos = [];
  String? _cleGemini;
  bool _cleChargee = false;
  bool _enCours = false;
  String? _erreurPhoto;
  String? _errorMessage;
  LeconImportee? _apercu;

  @override
  void initState() {
    super.initState();
    _chargerCle();
  }

  Future<void> _chargerCle() async {
    final cle = await lireCleGemini();
    if (!mounted) return;
    setState(() {
      _cleGemini = cle;
      _cleChargee = true;
    });
  }

  @override
  void dispose() {
    _jsonController.dispose();
    _precisionController.dispose();
    super.dispose();
  }

  Future<void> _saisirCleSurPlace() async {
    final res = await demanderEtEnregistrerCleGemini(
      context,
      cleActuelle: _cleGemini,
    );
    if (!res.modifie || !mounted) return;
    setState(() {
      _cleGemini = res.cle;
      _erreurPhoto = null;
    });
  }

  Future<void> _prendrePhoto() async {
    if (_photos.length >= 3 || _enCours) return;
    setState(() => _erreurPhoto = null);
    try {
      final photo = await prendrePhotoAppareil();
      if (!mounted || photo == null) return;
      setState(() {
        if (_photos.length < 3) _photos.add(photo);
        _apercu = null;
      });
    } on ErreurGeminiLecon catch (e) {
      if (!mounted) return;
      setState(() => _erreurPhoto = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _erreurPhoto = "Impossible d'ajouter la photo.");
    }
  }

  Future<void> _choisirImages() async {
    if (_photos.length >= 3 || _enCours) return;
    setState(() => _erreurPhoto = null);
    try {
      final choisies = await choisirImagesAppareil();
      if (!mounted || choisies.isEmpty) return;
      setState(() {
        for (final p in choisies) {
          if (_photos.length >= 3) break;
          _photos.add(p);
        }
        _apercu = null;
      });
    } on ErreurGeminiLecon catch (e) {
      if (!mounted) return;
      setState(() => _erreurPhoto = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _erreurPhoto = "Impossible de lire l'image choisie.");
    }
  }

  Future<void> _fabriquerAvecGemini() async {
    final cle = _cleGemini;
    if (cle == null || _photos.isEmpty || _enCours) return;
    setState(() {
      _enCours = true;
      _erreurPhoto = null;
      _apercu = null;
    });
    try {
      final lecon = await genererLeconDepuisPhotos(
        apiKey: cle,
        photos: List.of(_photos),
        commentaireParent: _precisionController.text,
      );
      if (!mounted) return;
      setState(() => _apercu = lecon);
    } on ErreurGeminiLecon catch (e) {
      if (!mounted) return;
      setState(() => _erreurPhoto = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _erreurPhoto = 'Erreur inattendue pendant la création.',
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  void _validerApercu() {
    final apercu = _apercu;
    if (apercu == null) return;
    widget.onLessonImported(apercu.matiere, apercu.lecon);
    Navigator.pop(context);
  }

  Future<void> _openClaude() async {
    await ouvrirLien(
      'https://claude.ai/new?q=Le%C3%A7on%20pour%20le%20Labo%20d%27%C3%89mile',
    );
  }

  Future<void> _pasteAndImport() async {
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {
      setState(() {
        _errorMessage =
            "⚠️ Le navigateur a bloqué l'accès au presse-papiers. "
            'Colle le texte manuellement dans le champ ci-dessous.';
      });
      return;
    }
    final text = data?.text ?? '';
    if (text.isEmpty) {
      setState(() {
        _errorMessage =
            "⚠️ Le presse-papiers est vide. Copie d'abord le JSON "
            'depuis Claude, puis réessaie.';
      });
      return;
    }
    _jsonController.text = text;
    _importJsonLesson();
  }

  void _importJsonLesson() {
    setState(() => _errorMessage = null);
    final rawText = _jsonController.text.trim();
    if (rawText.isEmpty) return;

    try {
      final res = analyserJsonLecon(rawText);
      widget.onLessonImported(res.matiere, res.lecon);
      Navigator.pop(context);
    } on FormatException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() {
        _errorMessage =
            '❌ Code JSON mal copié ou invalide. Vérifie la syntaxe.';
      });
    }
  }

  Widget _blocPhotoGemini() {
    final limiteAtteinte = _photos.length >= 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '📸 Créer une leçon depuis une photo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: LaboPalette.ink,
          ),
        ),
        const SizedBox(height: 8),
        if (_cleChargee && _cleGemini == null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: LaboShape.card,
              border: Border.all(color: LaboPalette.or),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enregistre une seule fois ta clé Gemini gratuite pour '
                  'transformer une photo en leçon :',
                  style: TextStyle(fontSize: 13, color: LaboPalette.ink),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _enCours ? null : _saisirCleSurPlace,
                  icon: const Icon(Icons.key),
                  label: const Text(
                    'Enregistrer ma clé Gemini gratuite',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LaboPalette.nuit,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (peutPrendrePhoto)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (limiteAtteinte || _enCours)
                      ? null
                      : _prendrePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Prendre en photo'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (limiteAtteinte || _enCours)
                      ? null
                      : _choisirImages,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galerie'),
                ),
              ),
            ],
          )
        else
          OutlinedButton.icon(
            onPressed: (limiteAtteinte || _enCours) ? null : _choisirImages,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choisir une photo de la leçon'),
          ),
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _photos.length; i++)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _photos[i].octets,
                        width: 78,
                        height: 78,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (!_enCours)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _photos.removeAt(i);
                            _apercu = null;
                          }),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: LaboPalette.rouge,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _precisionController,
          enabled: !_enCours,
          decoration: const InputDecoration(
            hintText:
                "Précision pour l'IA (facultatif, ex : CE2, table de 7…)",
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: (_photos.isEmpty || _enCours || _cleGemini == null)
                ? null
                : _fabriquerAvecGemini,
            icon: const Icon(Icons.auto_awesome),
            label: const Text(
              'Fabriquer la leçon avec Gemini',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: LaboPalette.encre,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: LaboShape.card),
            ),
          ),
        ),
        if (_enCours) ...[
          const SizedBox(height: 12),
          const Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Gemini lit la photo et prépare la leçon (15 à 20 s)…',
                  style: TextStyle(fontSize: 13, color: LaboPalette.muted),
                ),
              ),
            ],
          ),
        ],
        if (_erreurPhoto != null) ...[
          const SizedBox(height: 10),
          Text(
            _erreurPhoto!,
            style: const TextStyle(
              color: LaboPalette.rouge,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
        if (_apercu != null) ...[
          const SizedBox(height: 12),
          _CarteApercuLecon(
            apercu: _apercu!,
            onValider: _validerApercu,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final avecPhoto = peutChoisirImage;
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
            const Row(
              children: [
                Text('📸', style: TextStyle(fontSize: 24)),
                SizedBox(width: 8),
                Text(
                  'Ajouter une leçon',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: LaboPalette.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (avecPhoto) ...[
              _blocPhotoGemini(),
              const SizedBox(height: 12),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: !avecPhoto,
              title: const Text(
                '📋 Ou coller un code JSON manuellement',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: LaboPalette.muted,
                ),
              ),
              children: [
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openClaude,
                    icon: const Icon(
                      Icons.auto_awesome,
                      color: Colors.deepPurple,
                    ),
                    label: const Text(
                      'Créer une leçon avec Claude ✨',
                      style: TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.deepPurple),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _jsonController,
                  maxLines: 5,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Colle le code JSON de Claude ici...',
                    border: const OutlineInputBorder(),
                    fillColor: Colors.grey.shade50,
                    filled: true,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: _errorMessage!.startsWith('⚠️')
                          ? Colors.orange.shade800
                          : LaboPalette.rouge,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _pasteAndImport,
                          icon: const Icon(Icons.content_paste),
                          label: const Text(
                            'Coller et importer',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: LaboShape.card,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _importJsonLesson,
                          icon: const Icon(Icons.download_done),
                          label: const Text(
                            'Analyser 🚀',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LaboPalette.encre,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: LaboShape.card,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CarteApercuLecon extends StatelessWidget {
  final LeconImportee apercu;
  final VoidCallback onValider;

  const _CarteApercuLecon({required this.apercu, required this.onValider});

  @override
  Widget build(BuildContext context) {
    final l = apercu.lecon;
    final badge = separerBadgeSucces(l.succes, l.titre);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LaboPalette.good, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            apercu.matiere,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: LaboPalette.muted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l.titre,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: LaboPalette.ink,
            ),
          ),
          if (l.succes != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LaboPalette.or, width: 1.5),
              ),
              child: Row(
                children: [
                  BadgeRond(
                    diametre: 42,
                    cleIcone: choisirCleIconeBadge(
                      badge.nom,
                      l.titre,
                      apercu.matiere,
                    ),
                    niveau: NiveauBadge.or,
                    emoji: badge.emoji == '🏅' ? null : badge.emoji,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      badge.nom,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: LaboPalette.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${l.astuces.length} astuces · '
            '${l.exercices.length} exercices · '
            '${l.quiz.length} quiz',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: LaboPalette.ink,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onValider,
              icon: const Icon(Icons.check_circle),
              label: const Text(
                '✅ Ajouter cette leçon au Labo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: LaboPalette.good,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: LaboShape.card),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

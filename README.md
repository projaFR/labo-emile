# 🔬 Labo d'Émile — version 2.0.0

Application éducative Flutter (vraie appli Android `fr.thibaut.laboemile`, et PWA web) pour enfants, conçue pour apprendre en s'amusant grâce à un système de leçons injectées par l'IA.

---

## 📱 Fonctionnalités

### Nouveautés de la version 2.0
- **🌙 Leçon du soir** : l'onglet « Aujourd'hui » propose la leçon à faire et un bouton « Commencer / Continuer »
- **🧭 Parcours guidé** : Astuces, puis Entraînement, puis Défi Chrono, avec un récapitulatif et des étoiles à la fin
- **🧠 Mémoire par question et Révision du jour** : chaque question revient au bon moment (boîtes de révision) ; « Réviser quand même » reprend les plus faibles
- **🏆 Trophées** : niveau, diamants, combo, étoiles et progression
- **🌿 Séances douces** : les exercices déjà vus passent après les nouveaux, sans pression
- **💾 Sauvegarde / restauration** de la progression (Espace Parent)

### 3 modules d'apprentissage
- **🃏 Astuces** — Flashcards avec retournement animé (« dis-la dans ta tête » avant de retourner ; les cartes « À revoir » reviennent dans le tour)
- **🎯 Entraînement** — Séances de 10 exercices tirés de la leçon (à trous et QCM) ; 2 essais avec indice, puis la bonne réponse est montrée
- **⏱️ Défi Chrono** — Quiz avec temps réglable (sans / 15 s / 30 s, 30 s par défaut) ; le temps écoulé n'est pas une faute

### Système de récompenses
- **💎 Diamants** gagnés à chaque bonne réponse (exercices, quiz) ; 1 diamant par paquet de cartes fini (une fois par jour), rien pour « Maîtrisé »
- **🔥 Combo** : x3 diamants après 5 bonnes réponses consécutives ; une erreur fait redescendre le combo d'un cran
- **⭐ Étoiles** par leçon (Astuces : paquet fini sans « À revoir » ; Entraînement : séance toute juste, au besoin au 2e essai ; Chrono : tout juste)
- **🎊 Confettis** à chaque étoile débloquée
- **100 niveaux RPG** avec 10 titres qui changent tous les 10 niveaux :
  - Nv.1-10 : 🥚 Oeuf Mystérieux
  - Nv.11-20 : 🐣 Poussin Curieux
  - Nv.21-30 : 🗡️ Recrue Courageuse
  - Nv.31-40 : 🛡️ Chevalier Junior
  - Nv.41-50 : 🏹 Archer Savant
  - Nv.51-60 : 🔮 Mage des Formules
  - Nv.61-70 : 🐉 Dompteur de Dragons
  - Nv.71-80 : ⚡ Maître du Tonnerre
  - Nv.81-90 : 💫 Élu des Étoiles
  - Nv.91-100 : 👑 Dieu du Savoir

### Sons & haptique
- Son de succès (notes montantes) et d'erreur (notes descendantes)
- Vibrations légères/fortes selon le résultat
- Sons générés synthétiquement en mémoire (aucun fichier asset requis)

### Espace Parent (protégé par PIN)
- Injection de leçons via JSON généré par Gemini
- Ajout/remise à zéro des diamants
- Réglages : sons, vibrations, temps du Défi Chrono
- Suppression de leçons
- Changement du code PIN
- **Copier la sauvegarde** / **Restaurer une sauvegarde** (voir plus bas)

### Launch screen
- Écran d'accueil animé avec étoiles flottantes et logo 🔬

---

## 🏗️ Architecture

```
lib/
├── main.dart                  # Point d'entrée, launch screen
├── data/
│   └── database.dart          # Leçons par défaut
├── models/
│   └── lesson_model.dart      # Modèles de données (LessonModel, ExerciseModel, QuizModel...)
├── services/
│   └── sound_service.dart     # Sons synthétiques WAV
└── views/
    ├── home_screen.dart       # Écran principal, navigation, diamants, niveaux
    ├── launch_screen.dart     # Écran de démarrage animé
    ├── flashcards_view.dart   # Module Astuces
    ├── exercise_view.dart     # Module Entraînement
    ├── quiz_view.dart         # Module Défi Chrono
    └── parent_view.dart       # Espace Administration
```

---

## 📦 Dépendances

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  shared_preferences: ^2.2.0   # Persistance locale (diamants, étoiles, PIN)
  audioplayers: ^6.0.0          # Sons
  confetti: ^0.7.0              # Confettis
```

---

## 🤖 Générer des leçons avec Gemini

### Format JSON attendu

```json
{
  "matiere": "Mathématiques",
  "titre": "Les Fractions",
  "astuces": [
    { "question": "...", "reponse": "..." }
  ],
  "exercices": [
    {
      "question": "3 x [?] = 12",
      "consigne": "Trouve le nombre manquant :",
      "reponseAttendue": "4",
      "astuceErreur": "..."
    }
  ],
  "quiz": [
    {
      "question": "...",
      "options": ["A", "B", "C", "D"],
      "indexCorrect": 0
    }
  ]
}
```

### Types d'exercices

| Type | Quand l'utiliser | Clé de réponse |
|------|-----------------|----------------|
| **A — Trou numérique** | Réponse = un nombre | `reponseAttendue` (1 trou) ou `reponsesMultiples` (2+ trous) |
| **B — QCM texte** | Réponse = un mot/phrase | `options` + `reponseAttendue` |

### Règles importantes
- `[?]` dans la question = une case interactive
- TYPE A à 2+ trous → `reponsesMultiples` obligatoire (même nombre que les `[?]`)
- TYPE B → toujours exactement 0 ou 1 `[?]` dans la question
- Les valeurs numériques sans espaces (`"1000"` et non `"1 000"`)

---

## 🚀 Installation

### Prérequis
- Flutter SDK 3.9+
- Dart SDK 3.0+
- Android SDK (pour build APK)

### Lancer en développement
```bash
flutter pub get
flutter run -d web-server --web-port 8080  # Web
flutter run -d emulator-5554               # Émulateur Android
```

### Compiler l'APK Android (version 2.0)
```bash
flutter build apk --release
# APK : build/app/outputs/flutter-apk/app-release.apk
# (copie conseillée : dist/labo-emile-2.0.0.apk)
```
L'appli est signée avec la clé de debug de l'ordinateur (comme Réviser) : toujours compiler sur le **même ordinateur** pour que les mises à jour s'installent par-dessus. Le workflow GitHub « Build APK » est en lancement manuel seulement (sa clé change à chaque fois : inutilisable pour les mises à jour).

### Installer l'APK en USB
1. Sur le téléphone : Paramètres, À propos, appuyer 7 fois sur « Numéro de build », puis activer « Débogage USB » dans les options pour les développeurs.
2. Brancher le téléphone, accepter l'autorisation sur l'écran.
3. `adb install -r dist/labo-emile-2.0.0.apk` (ou copier le fichier sur le téléphone et l'ouvrir pour l'installer).
4. La 2.0 s'installe **à côté** de l'ancienne appli (identifiant différent) et ne reprend rien toute seule : voir « Sauvegarde ».

### Version web (PWA)
```bash
flutter build web --release --base-href "/labo-emile/"
```

### Version Windows (vraie appli PC)
Prérequis : Visual Studio 2022 avec la charge « Développement Desktop en C++ » (et Flutter avec Windows activé).

```bash
flutter build windows --release
```
- Résultat : `build\windowsdunner\Release\labo_emile.exe` (fenêtre « Labo d'Émile », 520 × 900 au départ, redimensionnable ; le contenu reste centré à 720 px max).
- Lancer : double-clic sur `Labo_PC.bat` (à la racine) ou sur `labo_emile.exe`.
- Raccourci (à faire toi-même) : clic droit sur `Labo_PC.bat` ou `labo_emile.exe` > « Afficher plus d'options » > « Créer un raccourci », puis glisser le raccourci sur le Bureau. Pour l'épingler à la barre des tâches, utiliser le raccourci de `labo_emile.exe`.
- Données : `%APPDATA%r.thibaut\Labo d'Emile\shared_preferences.json` (créé à la première sauvegarde de progression). Supprimer ce fichier remet le Labo à zéro.
- Transférer la progression du téléphone au PC : sur le téléphone, Espace Parent > « Copier la sauvegarde », envoyer le texte au PC (message à soi-même, par exemple) ; sur le PC, Espace Parent > « Restaurer une sauvegarde », coller, confirmer. Dans l'autre sens, c'est pareil.

**Aucune DLL de plugin (Smart App Control).** Smart App Control bloque les DLL de plugins Flutter. Le dossier `Release` ne contient donc que `labo_emile.exe`, `flutter_windows.dll` et `data\`. La technique :
- `windows\CMakeLists.txt` n'inclut plus `flutter/generated_plugins.cmake` (que `flutter pub get` régénère avec audioplayers et url_launcher) et `windowsunner\CMakeLists.txt` ne compile plus `generated_plugin_registrant.cc` ; `flutter_window.cpp` n'appelle plus `RegisterPlugins`. Ces trois fichiers ne sont jamais réécrits par Flutter, donc `pub get` et `build` ne défont rien.
- Son : sous Windows, `lib/services/lecteur_son_io.dart` joue le WAV en mémoire avec `PlaySound` (`winmm.dll`, via `dart:ffi` et le paquet `ffi`, Dart pur). Android et web gardent `audioplayers`.
- Liens (« Créer avec Claude ») : `lib/services/ouvrir_lien_io.dart` utilise `cmd /c start`. Android et web gardent `url_launcher`.
- `shared_preferences` et `confetti` sont du Dart pur.
- Si on ajoute un jour un plugin natif, il ne fonctionnera pas sous Windows tant qu'on ne le déclare pas à la main dans `windows\CMakeLists.txt` (et il risque d'être bloqué).

---

## 💾 Persistance des données

Toutes les données sont stockées localement via `SharedPreferences` :

| Clé | Description |
|-----|-------------|
| `emile_diamonds` | Total de diamants |
| `parent_pin` | Code PIN parent |
| `{titre}_star_astuces` | Étoile module Astuces |
| `{titre}_star_train` | Étoile module Entraînement |
| `{titre}_star_quiz` | Étoile module Défi Chrono |

### Sauvegarde / restauration
Espace Parent, rubrique « Sauvegarde de la progression » :
- **Copier la sauvegarde** copie un texte JSON (`sauvegardeVersion: 1`) dans le presse-papiers : diamants, étoiles, leçons importées, mémoire par question, réglages (sons, vibrations, chrono) et clés de séance. Le code parent n'est jamais inclus. Le niveau se recalcule avec les diamants.
- **Restaurer une sauvegarde** : coller le texte, vérification, résumé (leçons, niveau, diamants), confirmation. En cas d'erreur rien n'est modifié ; l'état d'avant est gardé dans la clé `sauvegarde_avant_restauration`.

---

## 📋 Versions

### v2.0.0 — Vraie appli Android
- Identifiant `fr.thibaut.laboemile`, version 2.0.0+6, leçon du soir, parcours guidé, mémoire par question, Trophées, séances douces, sauvegarde/restauration

### v1.0.0 — Première version complète
- Système de 3 modules (Astuces, Entraînement, Défi Chrono)
- Injection de leçons JSON via espace parent
- 100 niveaux RPG avec progression exponentielle
- Sons synthétiques + vibrations haptiques
- Confettis sur récompenses
- Launch screen animé
- Ordre aléatoire des questions et options
- Validation JSON à l'import (détection des erreurs de format)
- Suppression de leçons fonctionnelle
## Régénérer l'icône de l'appli

1. `flutter test tool/generer_icone_test.dart` repeint le widget `MicroscopeIcon` dans `assets/` et `web/` (hors de `test/`, donc non lancé par `flutter test`).
2. `dart run flutter_launcher_icons` régénère les icônes Android (mipmaps et icône adaptative).
3. Remettre `pubspec.lock` tel quel (`git checkout -- pubspec.lock`) s'il a bougé.

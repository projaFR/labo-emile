# 🔬 Labo d'Émile

Application mobile éducative Flutter pour enfants, conçue pour apprendre en s'amusant grâce à un système de leçons injectées par l'IA.

---

## 📱 Fonctionnalités

### 3 modules d'apprentissage
- **🃏 Astuces** — Flashcards avec retournement animé (système Leitner : les cartes ratées reviennent)
- **🎯 Entraînement** — Exercices à trous et QCM avec cases interactives
- **⏱️ Défi Chrono** — Quiz contre la montre avec bonus de rapidité

### Système de récompenses
- **💎 Diamants** gagnés à chaque bonne réponse
- **🔥 Combo** : x3 diamants après 5 bonnes réponses consécutives
- **⭐ Étoiles** par leçon (une par module complété sans erreur)
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
- Suppression de leçons
- Changement du code PIN

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

### Générer un APK
```bash
flutter build apk --debug
# APK disponible dans : build/app/outputs/flutter-apk/app-debug.apk
```

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

---

## 📋 Versions

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
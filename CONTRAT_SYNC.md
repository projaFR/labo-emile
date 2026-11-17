# Contrat de synchronisation Firebase — Le Labo d'Émile

Le Labo d'Émile synchronise ses leçons et la progression d'Émile entre le téléphone Android et le PC Windows en passant uniquement par l'API REST de Firebase (`package:http`, aucune DLL sous Windows).

Les collections du Labo sont **complètement séparées** des collections de **Réviser** (`packs/` et `users/`).

---

## 1. Collections Firestore (projet `reviser-bdd1a`)

1. **`labo_lecons/{leconId}`** — une leçon importée ou créée par photo :
   - `matiere` (string) : matière de la leçon (ex. `"Français"`).
   - `titre` (string) : titre classique de la leçon.
   - `json` (string) : JSON complet de `LessonModel` (`titre`, `succes` optionnel, `astuces`, `exercices`, `quiz`).
   - `modifieLe` (string) : horodatage ISO-8601 UTC (`2026-11-17T00:30:00.000Z`).
   - `supprimee` (boolean) : `true` si la leçon a été supprimée dans l'Espace Parent (pour propager la suppression sans ressusciter la leçon sur l'autre appareil).

2. **`labo_progression/emile`** — progression fusionnée d'Émile :
   - `json` (string) : JSON contenant `diamants`, `diamantsModifieLe`, `resetLe`, `derniereLeconImportee`, `revisionDiamantsJour`, `etoiles`, `cartesDiamant`, `seanceVus`, `memoireJson`.
   - `modifieLe` (string) : horodatage ISO-8601 UTC de la dernière mise à jour.

---

## 2. Règles Firestore (`firestore.rules` dans la console Firebase)

Copie-colle ce bloc complet dans **Console Firebase → Firestore Database → Règles** puis clique sur **Publier** :

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Règles existantes de Réviser (inchangées) :
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    match /packs/{coursId} {
      allow read: if request.auth != null
        && request.auth.token.email == 'thibautlb@gmail.com'
        && request.auth.token.email_verified == true;
      allow write: if false;
    }

    // Règles du Labo d'Émile (collections séparées) :
    match /labo_lecons/{leconId} {
      allow read, write: if request.auth != null;
    }
    match /labo_progression/{docId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## 3. Mise en route (2 étapes simples avec Google)

1. **Publier les règles Firestore** : dans **Console Firebase → Firestore → Règles**, colle les règles ci-dessus et clique sur **Publier** *(rien à toucher dans Authentication ni dans Paramètres si tu utilises la connexion Google comme Réviser)*.
2. **Connecter le PC puis le téléphone** :
   - Sur le **PC**, ouvre **Le Labo d'Émile → Leçons → ⚙️ Espace Parent → ☁️ Configurer le compte Firebase** → clique sur **🔵 Se connecter avec Google (comme Réviser)** *(les identifiants de `Reviser/assets/firebase_config.json` sont détectés tout seuls à l'exécution)*.
   - Branche le téléphone en USB et clique dans le même écran PC sur **📱 Transférer ce compte au téléphone (USB)** *(ou connecte-toi directement avec Google sur le téléphone)*.

*(En secours, une connexion manuelle par e-mail/mot de passe + clé API Web reste disponible dans « Autre méthode ».)*

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

## 3. Mise en route (3 étapes rapides)

1. **Créer le compte Labo** : dans **Console Firebase → Authentication → Sign-in method**, active **Adresse e-mail/Mot de passe**, puis dans **Users → Ajouter un utilisateur**, crée un compte dédié (ex. `labo@emile.local` avec un mot de passe de ton choix).
2. **Publier les règles** : colle les règles ci-dessus dans **Firestore Database → Règles** et publie.
3. **Connecter tes appareils** : dans le **Labo d'Émile → Mes leçons → ⚙️ Espace Parent → ☁️ Configurer le compte Firebase** (sur le téléphone ET sur le PC), colle ta **Clé API Web Firebase** (trouvable dans *Paramètres du projet → Général*, ou en collant le contenu de ton JSON de config Firebase), puis saisis l'e-mail et le mot de passe du compte Labo.

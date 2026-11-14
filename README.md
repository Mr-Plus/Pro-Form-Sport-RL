# Rameur — Pro-Form Sport RL (`proform_rower_app`)

Application Flutter dédiée au pilotage et au suivi d'entraînements en Bluetooth Low Energy (BLE) pour le rameur **Pro-Form Sport RL** (`PFRW48121-INT.0`).

## Fonctionnalités principales

- **Connexion BLE & Pilotage Résistance (1 à 24)** (`lib/services/proform_ble_service.dart`) :
  - Connexion directe au rameur Pro-Form Sport RL via `flutter_blue_plus`.
  - Réception et décodage temps réel de la télémétrie (puissance en Watts, cadence SPM, allure `/500m`, distance, coups de rame, calories, durée / mode minuteur).
  - Envoi automatique et manuel des consignes de résistance magnétique SMR (niveaux 1 à 24) selon les paliers de la séance.
- **Mode Paysage Temps Réel** (`lib/screens/landscape_session_screen.dart`, `lib/services/live_session_service.dart`) :
  - Bascule automatique sur le tableau de bord d'entraînement en tournant le téléphone en mode paysage, avec sélection automatique de la prochaine séance du programme actif (ou séance libre).
  - Auto-démarrage dès le premier coup de rame, détection automatique des pauses avec suivi de la durée de pause, et cumul continu des métriques même lorsque la console du rameur se remet à zéro ou décompte à l'envers.
- **Coach Vocal Intelligent** (`lib/services/voice_coach_service.dart`) :
  - Annonces des blocs, compte à rebours avant transitions, confirmation de la cadence cible (SPM), alertes en cas de baisse de rythme, résumé périodique toutes les 5 minutes, résumé motivant en pause automatique et félicitations de fin de séance via `flutter_tts`.
- **Programmes, Planification & Coach IA** (`lib/screens/program_screen.dart`, `lib/screens/workouts_ai_screen.dart`, `lib/services/ai_coach_service.dart`) :
  - Création et gestion de programmes hebdomadaires (jours, heure, réordonnancement des séances, modification des blocs en minutes et résistance).
  - Génération de séances et de programmes personnalisés (en local ou via API Gemini) adaptés au niveau et à l'objectif de l'utilisateur.
  - Notifications de rappel locales (`lib/services/notification_service.dart`).
- **Historique & Profil Utilisateur** (`lib/screens/sessions_history_screen.dart`, `lib/screens/user_profile_screen.dart`) :
  - Suivi des séances enregistrées avec graphiques télémétriques (`lib/widgets/telemetry_charts.dart`).
  - Configuration du profil (poids, taille, âge, niveau, objectif, guide des objectifs) et paramètres BLE/IA (`lib/screens/settings_screen.dart`).
- **Stockage local** (`lib/services/app_state_service.dart`) :
  - Persistance locale sur l'appareil via `shared_preferences`.

## Architecture du projet

```text
lib/
├── main.dart
├── models/
│   └── models.dart
├── screens/
│   ├── home_screen.dart
│   ├── landscape_session_screen.dart
│   ├── program_screen.dart
│   ├── sessions_history_screen.dart
│   ├── settings_screen.dart
│   ├── user_profile_screen.dart
│   └── workouts_ai_screen.dart
├── services/
│   ├── ai_coach_service.dart
│   ├── app_state_service.dart
│   ├── live_session_service.dart
│   ├── notification_service.dart
│   ├── proform_ble_service.dart
│   └── voice_coach_service.dart
├── theme/
│   └── app_theme.dart
└── widgets/
    └── telemetry_charts.dart
```

## Prérequis & Développement

- Flutter / Dart SDK (`^3.13.4` défini dans `pubspec.yaml`)

```bash
# Installer les dépendances
flutter pub get

# Lancer les tests unitaires et widget
flutter test
```

## Build & Déploiement Android

Pour compiler l'APK release et mettre à jour l'application sur un appareil Android connecté **sans effacer les données locales (`SharedPreferences`)**, utiliser `adb install -r` :

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

> **Note :** `flutter install` désinstalle l'ancienne version avant d'installer la nouvelle, ce qui supprime les données locales. Préférer `adb install -r` lors des mises à jour.

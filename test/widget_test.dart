import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proform_rower_app/main.dart';
import 'package:proform_rower_app/models/models.dart';
import 'package:proform_rower_app/services/ai_coach_service.dart';
import 'package:proform_rower_app/services/app_state_service.dart';
import 'package:proform_rower_app/services/live_session_service.dart';
import 'package:proform_rower_app/services/proform_ble_service.dart';
import 'package:proform_rower_app/services/voice_coach_service.dart';

void main() {
  group('Protocole BLE Pro-Form Sport RL (PFRW48121-INT.0)', () {
    test(
      'Les 24 niveaux de résistance SMR génèrent des trames de 20 octets valides',
      () {
        expect(ProFormSportRLProtocol.resistanceCommands.length, 24);
        for (int level = 1; level <= 24; level++) {
          final frame = ProFormSportRLProtocol.getResistanceFrame(level);
          expect(frame.length, 20);
          expect(frame[0], 0xff);
          expect(frame[1], 0x0d);
        }
        final res1 = ProFormSportRLProtocol.getResistanceFrame(1);
        expect(res1[11], 0x76);
        expect(res1[12], 0x01);
        expect(res1[14], 0x9b);

        final res24 = ProFormSportRLProtocol.getResistanceFrame(24);
        expect(res24[11], 0xe6);
        expect(res24[12], 0x26);
        expect(res24[14], 0x30);
      },
    );

    test(
      'Décodage des 24 niveaux de résistance dans la trame télémétrique',
      () {
        for (int level = 1; level <= 24; level++) {
          final byte11 = ProFormSportRLProtocol.encodeResistanceByte(level);
          expect(
            ProFormSportRLProtocol.decodeResistanceFromTelemetryByte(byte11),
            level,
          );
        }
      },
    );

    test(
      'Décodage des trames réelles sportrl_log.zip (0xff 0x11, 0x00 0x12, 0x01 0x12, 0xff 0x0e)',
      () {
        // Trame A réelle : ff 11 ... cadence=39 (0x27), speed=0
        final frameA = <int>[
          0xff, 0x11, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x06, 0x00, 0x27, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x45,
        ];
        final decodedA = ProFormSportRLProtocol.decodeTelemetryPacket(frameA);
        expect(decodedA, isNotNull);
        expect(decodedA!.isCadenceSpeedFrame, isTrue);
        expect(decodedA.cadenceSpm, 39);

        // Trame B réelle : 00 12 01 04 02 2e 04 2e 02 ... res=0x01 (niv 1), watts=64 (0x0040), dist=12 (0x000c)
        final frameB = <int>[
          0x00, 0x12, 0x01, 0x04, 0x02, 0x2e, 0x04, 0x2e, 0x02, 0x00,
          0x00, 0x01, 0x40, 0x00, 0x0c, 0x00, 0x15, 0x00, 0x00, 0x00,
        ];
        final decodedB = ProFormSportRLProtocol.decodeTelemetryPacket(frameB);
        expect(decodedB, isNotNull);
        expect(decodedB!.isWattsResistanceDistanceFrame, isTrue);
        expect(decodedB.resistanceLevel, 1);
        expect(decodedB.watts, 64);
        expect(decodedB.distanceMeters, 12.0);
        expect(decodedB.caloriesKcal, isNull); // Calories extraites uniquement de ff 0e

        // Trame B avec sentinelle de pause (distance = 0xFFFF / 65535) : la distance doit être nulle (ignorée)
        final frameBPause = <int>[
          0x00, 0x12, 0x01, 0x04, 0x02, 0x2e, 0x04, 0x2e, 0x02, 0x00,
          0x00, 0x01, 0x00, 0x00, 0xff, 0xff, 0x18, 0x00, 0x00, 0x00,
        ];
        final decodedBPause =
            ProFormSportRLProtocol.decodeTelemetryPacket(frameBPause);
        expect(decodedBPause, isNotNull);
        expect(decodedBPause!.distanceMeters, isNull);
        expect(decodedBPause.caloriesKcal, isNull);

        // Trame C réelle : 01 12 00 00 00 ... strokes = 5 (0x0005 aux octets 5..6)
        final frameC = <int>[
          0x01, 0x12, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ];
        final decodedC = ProFormSportRLProtocol.decodeTelemetryPacket(frameC);
        expect(decodedC, isNotNull);
        expect(decodedC!.isStrokesFrame, isTrue);
        expect(decodedC.strokesCount, 5);

        // Trame D réelle : ff 0e ... 2c 01 ... elapsed = 12s (0x000c aux octets 11..12)
        final frameD = <int>[
          0xff, 0x0e, 0x00, 0x00, 0x2c, 0x01, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x0c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ];
        final decodedD = ProFormSportRLProtocol.decodeTelemetryPacket(frameD);
        expect(decodedD, isNotNull);
        expect(decodedD!.isElapsedTimeFrame, isTrue);
        expect(decodedD.elapsedSeconds, 12);

        // Trames réelles capturées sur la console Pro-Form Sport RL physique :
        // 1. Coups de rame réels (28 coups)
        final realFrameC = <int>[
          0x01, 0x12, 0x00, 0x00, 0x01, 0x1c, 0x00, 0x00, 0x00, 0x02,
          0x1c, 0x00, 0x00, 0x00, 0x1c, 0x00, 0x00, 0x00, 0xc0, 0x88,
        ];
        final decodedRealC = ProFormSportRLProtocol.decodeTelemetryPacket(realFrameC);
        expect(decodedRealC, isNotNull);
        expect(decodedRealC!.isConsoleStrokesFrame, isTrue);
        expect(decodedRealC.consoleStrokes, 28);
        expect(decodedRealC.isConsolePaused, isFalse);

        // 2. Durée réelle (109s) et Calories réelles (5 kcal)
        final realFrameD = <int>[
          0xff, 0x0e, 0x05, 0x00, 0x2c, 0x01, 0x6d, 0x00, 0xb4, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x91, 0x00, 0x00, 0xc0, 0x88,
        ];
        final decodedRealD = ProFormSportRLProtocol.decodeTelemetryPacket(realFrameD);
        expect(decodedRealD, isNotNull);
        expect(decodedRealD!.isConsoleTimeFrame, isTrue);
        expect(decodedRealD.consoleElapsedSeconds, 109);
        expect(decodedRealD.caloriesKcal, 5.0);
        expect(decodedRealD.isConsolePaused, isFalse);

        // 3. Cumul de pause lu dans la trame D (pause cumulée de 5s, durée à 124s)
        final realFrameDPause = <int>[
          0xff, 0x0e, 0x00, 0x00, 0x2c, 0x01, 0x7c, 0x00, 0xb4, 0x00,
          0x00, 0x05, 0x00, 0x00, 0x00, 0x44, 0x00, 0x00, 0x00, 0x00,
        ];
        final decodedRealDPause = ProFormSportRLProtocol.decodeTelemetryPacket(realFrameDPause);
        expect(decodedRealDPause, isNotNull);
        expect(decodedRealDPause!.isConsolePaused, isFalse);
        expect(decodedRealDPause.consoleElapsedSeconds, 124);
        expect(decodedRealDPause.consolePauseSeconds, 5);

        // 4. Les trames de réponse handshake d'initialisation NE DOIVENT PAS être décodées comme télémétrie
        final initFrameC = <int>[
          0x01, 0x12, 0x00, 0x76, 0xe8, 0x2d, 0xe8, 0x03, 0x00, 0x24,
          0xf4, 0x00, 0xf4, 0x01, 0x01, 0x00, 0x01, 0x02, 0x00, 0x00,
        ];
        expect(ProFormSportRLProtocol.decodeTelemetryPacket(initFrameC), isNull);

        final initFrameD = <int>[
          0xff, 0x0e, 0x32, 0x32, 0x30, 0x31, 0x37, 0x2e, 0x30, 0x39,
          0x30, 0x38, 0x01, 0x2a, 0x03, 0xb1, 0x2e, 0x30, 0x36, 0x31,
        ];
        expect(ProFormSportRLProtocol.decodeTelemetryPacket(initFrameD), isNull);

        // 5. Trame réelle session utilisateur : 8 strokes, 3 calories, 104m
        // Trame A : octets 10-11 = 8 strokes (0x08 0x00), cadence 28 (0x1c)
        final userFrameA = <int>[
          0xff, 0x11, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x08, 0x00, 0x1c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ];
        final decodedUserA = ProFormSportRLProtocol.decodeTelemetryPacket(userFrameA);
        expect(decodedUserA, isNotNull);
        expect(decodedUserA!.isStrokeVelocityFrame, isTrue);
        expect(decodedUserA.consoleStrokes, 8);
        expect(decodedUserA.cadenceSpm, 28);

        // Trame B : octets 14-15 = 104m (0x68 0x00) avec b5=0x2e et b10=0x00
        final userFrameB = <int>[
          0x00, 0x12, 0x01, 0x04, 0x02, 0x2e, 0x14, 0x2e, 0x02, 0x02,
          0x00, 0x01, 0x40, 0x00, 0x68, 0x00, 0x00, 0x00, 0x00, 0x00,
        ];
        final decodedUserB = ProFormSportRLProtocol.decodeTelemetryPacket(userFrameB);
        expect(decodedUserB, isNotNull);
        expect(decodedUserB!.isPowerDistanceFrame, isTrue);
        expect(decodedUserB.distanceMeters, 104.0);

        // Trame D : octets 2-3 = 3 kcal (0x03 0x00)
        final userFrameD = <int>[
          0xff, 0x0e, 0x03, 0x00, 0x2c, 0x01, 0x26, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ];
        final decodedUserD = ProFormSportRLProtocol.decodeTelemetryPacket(userFrameD);
        expect(decodedUserD, isNotNull);
        expect(decodedUserD!.isConsoleTimeFrame, isTrue);
        expect(decodedUserD.caloriesKcal, 3.0);

        // 6. Trame parasite d'écho de handshake (00 12 01 04 02 20 14 20 02 02 0a 70 17 64 00 03 00 78 00 01)
        // b5 == 0x20 et b10 == 0x0a : DOIT ÊTRE REJETÉE (retourne null)
        // Empêche le pic à 1500W, les 768m fantômes et les 30720 kcal corrompues
        final handshakeEchoFrame = <int>[
          0x00, 0x12, 0x01, 0x04, 0x02, 0x20, 0x14, 0x20, 0x02, 0x02,
          0x0a, 0x70, 0x17, 0x64, 0x00, 0x03, 0x00, 0x78, 0x00, 0x01,
        ];
        expect(ProFormSportRLProtocol.decodeTelemetryPacket(handshakeEchoFrame), isNull);

        // 7. Trames réelles de la séance de 47s (17 coups, 13 kcal, 225m)
        final realSession17Strokes = <int>[
          0xff, 0x11, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x11, 0x00, 0x16, 0x85, 0x00, 0x72, 0x00, 0x00, 0x4d, 0xff,
        ];
        final decoded17Strokes = ProFormSportRLProtocol.decodeTelemetryPacket(realSession17Strokes);
        expect(decoded17Strokes, isNotNull);
        expect(decoded17Strokes!.consoleStrokes, 17);

        final realSession13Kcal = <int>[
          0xff, 0x0e, 0x0d, 0x00, 0x2c, 0x01, 0x00, 0x00, 0xb4, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00, 0xd7, 0x00, 0x00, 0xb8, 0x30,
        ];
        final decoded13Kcal = ProFormSportRLProtocol.decodeTelemetryPacket(realSession13Kcal);
        expect(decoded13Kcal, isNotNull);
        expect(decoded13Kcal!.caloriesKcal, 13.0);

        final realSession225m = <int>[
          0x00, 0x12, 0x01, 0x04, 0x02, 0x2e, 0x14, 0x2e, 0x02, 0x02,
          0x00, 0x00, 0x96, 0x00, 0xe1, 0x00, 0x00, 0x00, 0x46, 0x00,
        ];
        final decoded225m = ProFormSportRLProtocol.decodeTelemetryPacket(realSession225m);
        expect(decoded225m, isNotNull);
        expect(decoded225m!.distanceMeters, 225.0);
        expect(decoded225m.powerWatts, 150);

        // 8. Trame réelle 00 12 avec résistance > 1 (b10 != 0x00 : c0 09 = SMR 6, 150W, 1654m)
        final realRes6Frame = <int>[
          0x00, 0x12, 0x01, 0x04, 0x02, 0x2e, 0x14, 0x2e, 0x02, 0x02,
          0xc0, 0x09, 0x96, 0x00, 0x76, 0x06, 0x00, 0x00, 0x46, 0x00,
        ];
        final decodedRes6 = ProFormSportRLProtocol.decodeTelemetryPacket(realRes6Frame);
        expect(decodedRes6, isNotNull);
        expect(decodedRes6!.resistanceLevel, 6);
        expect(decodedRes6.powerWatts, 150);
        expect(decodedRes6.distanceMeters, 1654.0);
      },
    );
  });

  group('Sessions & Coach IA', () {
    test('Aucune fausse ancienne séance n\'est pré-remplie au démarrage', () async {
      SharedPreferences.setMockInitialValues({});
      final appState = AppStateService();
      await appState.init();
      expect(appState.sessions, isEmpty);
    });

    test(
      'Associer une session orpheline à un utilisateur recalcule les KCal selon son poids',
      () {
        final orphan = RowingSession(
          id: 's_test',
          userId: null,
          workoutTitle: 'Séance Console',
          startedAt: DateTime.now(),
          durationSeconds: 1200,
          distanceMeters: 4500,
          avgWatts: 180,
          maxWatts: 240,
          avgCadenceSpm: 26,
          avgResistance: 12,
          caloriesKcal: 200,
          strokesCount: 520,
          source: SessionSource.lateSyncConsole,
        );
        expect(orphan.isAssigned, isFalse);

        final user = UserProfile(
          id: 'u1',
          name: 'Matthieu',
          avatarEmoji: '🚣',
          colorValue: 0xFF00E5FF,
          weightKg: 80.0,
          heightCm: 180,
          age: 34,
          maxHeartRate: 186,
          level: FitnessLevel.intermediate,
          goal: WorkoutGoal.hiitWeightLoss,
          createdAt: DateTime.now(),
        );

        final assigned = orphan.assignToUser(user);
        expect(assigned.isAssigned, isTrue);
        expect(assigned.userId, 'u1');
        expect(assigned.caloriesKcal, greaterThan(250));
      },
    );

    test(
      'Coach IA génère une séance fractionnée et un programme complet calibrés',
      () async {
        final user = UserProfile(
          id: 'u1',
          name: 'Matthieu',
          avatarEmoji: '🚣',
          colorValue: 0xFF00E5FF,
          weightKg: 78.0,
          heightCm: 180,
          age: 34,
          maxHeartRate: 186,
          level: FitnessLevel.intermediate,
          goal: WorkoutGoal.hiitWeightLoss,
          createdAt: DateTime.now(),
        );

        final workout = await AiCoachService.generateCustomWorkout(
          user: user,
          userHistory: const [],
          durationMinutes: 20,
          focusPrompt: 'Fractionné 30/30 sprint',
          intensity: 'intense',
        );
        expect(workout.steps, isNotEmpty);
        expect(workout.isAiGenerated, isTrue);
        for (final s in workout.steps) {
          expect(s.targetResistance, inInclusiveRange(1, 24));
        }

        final program = await AiCoachService.generateTrainingProgram(
          user: user,
          userHistory: const [],
          weeksCount: 4,
          sessionsPerWeek: 3,
          avgSessionMinutes: 20,
          objectivePrompt: 'Perte de poids',
        );
        expect(program.workouts.length, 12);
        expect(program.trainingDays, isNotEmpty);
      },
    );
  });

  testWidgets(
    'Navigation sur les 4 onglets et ouverture du profil et des paramètres sans dépassement d\'écran',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final appState = AppStateService();
      await appState.init();
      final bleService = ProFormBleService();

      await tester.pumpWidget(
        ProFormRowerApp(
          appState: appState,
          bleService: bleService,
        ),
      );
      await tester.pumpAndSettle();

      // Titre de l'app 'Rameur'
      expect(find.text('Rameur'), findsOneWidget);

      // Menu bas : Accueil, Programmes, Séance, Historique
      expect(find.text('Accueil'), findsWidgets);
      expect(find.text('Programmes'), findsWidgets);
      expect(find.text('Séance'), findsWidgets);
      expect(find.text('Historique'), findsWidgets);

      // Sur l'Accueil : phrase du coach avec pseudo, icône connexion dans l'appbar, graph du programme
      expect(find.textContaining('Matthieu'), findsWidgets);
      expect(find.byTooltip('Connecter le rameur'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Onglet Programmes
      await tester.tap(find.text('Programmes').first);
      await tester.pumpAndSettle();
      expect(find.text('PROGRAMME EN COURS'), findsOneWidget);

      // Onglet Séance
      await tester.tap(find.text('Séance').first);
      await tester.pumpAndSettle();
      expect(find.text('Séances types'), findsOneWidget);
      expect(find.text('Création via IA'), findsOneWidget);

      // Onglet Historique
      await tester.tap(find.text('Historique').first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Aucune session enregistrée'), findsOneWidget);

      // Clic sur l'icône Profil dans le Header
      await tester.tap(find.byTooltip('Profil utilisateur'));
      await tester.pumpAndSettle();
      expect(find.text('Profil Utilisateur'), findsOneWidget);
      expect(find.text('INFORMATIONS PERSONNELLES'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Clic sur l'icône Paramètres dans le Header
      await tester.tap(find.byTooltip('Paramètres'));
      await tester.pumpAndSettle();
      expect(find.text('Paramètres'), findsOneWidget);
      expect(find.text('CONNEXION'), findsOneWidget);
      expect(find.text('NOTIFICATIONS'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Rotation en mode Paysage (844x390) : affichage live plein écran uniquement
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();

      // En mode Paysage : pas d'AppBar ni de NavigationBar
      expect(find.byType(NavigationBar), findsNothing);

      // Métriques plein écran
      expect(find.text('DURÉE'), findsOneWidget);
      expect(find.text('ALLURE'), findsOneWidget);
      expect(find.text('PUISSANCE'), findsOneWidget);
      expect(find.text('CADENCE'), findsOneWidget);
      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text('COUPS DE RAME'), findsOneWidget);
      expect(find.text('CALORIES'), findsOneWidget);
      expect(find.text('RÉSISTANCE SMR'), findsOneWidget);

      // Barre de contrôle
      expect(find.text('DÉMARRER'), findsOneWidget);
      expect(find.text('Coach'), findsOneWidget);

      // Démarrage de session en paysage
      await tester.tap(find.text('DÉMARRER'));
      await tester.pump();
      expect(find.text('ARRÊTER'), findsOneWidget);
    },
  );

  test(
    'VoiceCoachService annonce les transitions, détecte les coups de mou et félicite',
    () {
      final coach = VoiceCoachService();
      final user = UserProfile(
        id: 'u1',
        name: 'Matthieu',
        avatarEmoji: '🚣',
        colorValue: 0xFF00E5FF,
        weightKg: 78.0,
        heightCm: 180,
        age: 34,
        maxHeartRate: 186,
        level: FitnessLevel.intermediate,
        goal: WorkoutGoal.hiitWeightLoss,
        createdAt: DateTime.now(),
      );
      const stepWork = WorkoutStep(
        id: 's1',
        title: 'Sprint Explosif',
        type: StepType.work,
        durationSeconds: 30,
        targetResistance: 16,
        targetSpmMin: 28,
        targetSpmMax: 32,
        targetWatts: 200,
      );
      const stepRest = WorkoutStep(
        id: 's2',
        title: 'Récupération Active',
        type: StepType.rest,
        durationSeconds: 30,
        targetResistance: 6,
        targetSpmMin: 18,
        targetSpmMax: 21,
      );

      // 1. Avertissement à 10s de la fin du bloc
      coach.evaluateTick(
        user: user,
        telemetry: const RowerTelemetry(cadenceSpm: 29, powerWatts: 205),
        sessionElapsedSec: 20,
        sessionDistanceMeters: 100,
        samples: const [],
        workout: null,
        currentStep: stepWork,
        nextStep: stepRest,
        stepElapsedSec: 20,
        stepRemainingSec: 10,
      );
      expect(
        coach.lastMessageType,
        CoachMessageType.transitionWarning,
      );
      expect(coach.lastMessage, contains('10 secondes'));

      // 2. Félicitations au cap des 500m
      coach.evaluateTick(
        user: user,
        telemetry: const RowerTelemetry(cadenceSpm: 28, powerWatts: 195),
        sessionElapsedSec: 120,
        sessionDistanceMeters: 505,
        samples: const [],
        workout: null,
        currentStep: stepWork,
        nextStep: stepRest,
        stepElapsedSec: 15,
        stepRemainingSec: 15,
      );
      expect(coach.lastMessageType, CoachMessageType.praise);
      expect(coach.lastMessage, contains('500 mètres'));
    },
  );

  test(
    'Coach IA : reprise tranquille avec fractionné garantit toujours sprint > repos',
    () async {
      final user = UserProfile(
        id: 'u1',
        name: 'Matthieu',
        avatarEmoji: '🚣',
        colorValue: 0xFF00E5FF,
        weightKg: 78.0,
        heightCm: 180,
        age: 34,
        maxHeartRate: 186,
        level: FitnessLevel.intermediate,
        goal: WorkoutGoal.recovery,
        createdAt: DateTime.now(),
      );

      final workout = await AiCoachService.generateCustomWorkout(
        user: user,
        userHistory: const [],
        durationMinutes: 20,
        focusPrompt: 'reprise tranquille du rameur avec un peu de fractionné',
        intensity: 'douce',
      );

      expect(workout.steps.isNotEmpty, isTrue);

      final workSteps =
          workout.steps.where((s) => s.type == StepType.work).toList();
      final restSteps =
          workout.steps.where((s) => s.type == StepType.rest).toList();

      expect(workSteps.isNotEmpty, isTrue);
      expect(restSteps.isNotEmpty, isTrue);

      for (final work in workSteps) {
        for (final rest in restSteps) {
          expect(
            work.targetResistance,
            greaterThan(rest.targetResistance),
            reason:
                'La résistance de sprint (${work.targetResistance}) doit être strictement supérieure à celle du repos (${rest.targetResistance})',
          );
        }
      }
    },
  );

  test(
    'VoiceCoachService n\'utilise pas le pseudo de l\'utilisateur à chaque message',
    () {
      final coach = VoiceCoachService();
      final user = UserProfile(
        id: 'u1',
        name: 'Matthieu',
        avatarEmoji: '🚣',
        colorValue: 0xFF00E5FF,
        weightKg: 78.0,
        heightCm: 180,
        age: 34,
        maxHeartRate: 186,
        level: FitnessLevel.intermediate,
        goal: WorkoutGoal.hiitWeightLoss,
        createdAt: DateTime.now(),
      );

      const step1 = WorkoutStep(
        id: 's1',
        title: 'Bloc 1',
        type: StepType.work,
        durationSeconds: 30,
        targetResistance: 10,
        targetSpmMin: 24,
        targetSpmMax: 28,
      );
      const step2 = WorkoutStep(
        id: 's2',
        title: 'Bloc 2',
        type: StepType.rest,
        durationSeconds: 30,
        targetResistance: 4,
        targetSpmMin: 18,
        targetSpmMax: 20,
      );
      const step3 = WorkoutStep(
        id: 's3',
        title: 'Bloc 3',
        type: StepType.work,
        durationSeconds: 30,
        targetResistance: 12,
        targetSpmMin: 26,
        targetSpmMax: 30,
      );

      coach.onStepChanged(user: user, newStep: step1, stepIndex: 0, totalSteps: 3);
      final msg1 = coach.lastMessage;

      coach.onStepChanged(user: user, newStep: step2, stepIndex: 1, totalSteps: 3);
      final msg2 = coach.lastMessage;

      coach.onStepChanged(user: user, newStep: step3, stepIndex: 2, totalSteps: 3);
      final msg3 = coach.lastMessage;

      // Au moins un des messages de transition ne doit pas contenir le pseudo 'Matthieu'
      final containsCount = [msg1, msg2, msg3].where((m) => m.contains('Matthieu')).length;
      expect(containsCount, lessThan(3), reason: 'Le pseudo ne doit pas être répété à chaque réplique');
    },
  );

  group('LiveSessionService (auto-start & reprise données rameur)', () {
    test(
      'Démarre automatiquement dès le premier coup de rame sans bouton et adopte les données réelles du rameur',
      () async {
        SharedPreferences.setMockInitialValues({});
        final appState = AppStateService();
        await appState.init();

        final fakeBle = _FakeBleService();
        final voiceCoach = VoiceCoachService();
        final liveSession = LiveSessionService(
          appState: appState,
          bleService: fakeBle,
          voiceCoach: voiceCoach,
        );

        expect(liveSession.isRunning, isFalse);

        // L'utilisateur avait déjà commencé à ramer avant de connecter le Bluetooth
        fakeBle.pushTelemetry(
          isConnected: true,
          telemetry: RowerTelemetry(
            distanceMeters: 540.0,
            strokesCount: 42,
            elapsedSeconds: 115,
            powerWatts: 130,
            cadenceSpm: 24,
            speedKmh: 11.2,
            resistanceLevel: 10,
          ),
        );

        expect(liveSession.isRunning, isTrue);
        expect(liveSession.isPaused, isFalse);
        expect(liveSession.sessionDistanceMeters, 540.0);
        expect(liveSession.sessionStrokesCount, 42);
        expect(liveSession.sessionElapsedSeconds, 115);

        final summary = liveSession.stopAndBuildSummary();
        expect(summary, isNotNull);
        expect(summary!.distanceMeters, 540.0);
        expect(summary.strokesCount, 42);
        expect(summary.durationSeconds, 115);

        final session = summary.toWorkoutSession(appState.activeUser.id);
        expect(session.distanceMeters, 540.0);
        expect(session.strokesCount, 42);
        expect(session.workoutTitle, 'Session Libre');

        liveSession.dispose();
        voiceCoach.dispose();
      },
    );

    test(
      'Séance programmée : démarre automatiquement dès le premier coup de rame sans appui sur Démarrer',
      () async {
        SharedPreferences.setMockInitialValues({});
        final appState = AppStateService();
        await appState.init();

        final fakeBle = _FakeBleService();
        final voiceCoach = VoiceCoachService();
        final liveSession = LiveSessionService(
          appState: appState,
          bleService: fakeBle,
          voiceCoach: voiceCoach,
        );

        final workout = Workout(
          id: 'wk_test',
          title: 'Fractionné 10 min',
          description: 'Test auto-start',
          category: 'hiit',
          createdAt: DateTime.now(),
          steps: const [
            WorkoutStep(
              id: 'st1',
              title: 'Échauffement',
              type: StepType.warmup,
              durationSeconds: 300,
              targetResistance: 6,
              targetSpmMin: 20,
              targetSpmMax: 24,
            ),
          ],
        );

        liveSession.selectWorkout(workout);
        expect(liveSession.isRunning, isFalse);

        fakeBle.pushTelemetry(
          isConnected: true,
          telemetry: RowerTelemetry(
            distanceMeters: 15.0,
            strokesCount: 2,
            elapsedSeconds: 4,
            powerWatts: 95,
            cadenceSpm: 22,
            speedKmh: 9.5,
            resistanceLevel: 6,
          ),
        );

        expect(liveSession.isRunning, isTrue);
        expect(liveSession.selectedWorkout?.id, 'wk_test');
        expect(liveSession.sessionDistanceMeters, 15.0);
        expect(liveSession.sessionStrokesCount, 2);

        final summary = liveSession.stopAndBuildSummary();
        expect(summary, isNotNull);
        expect(summary!.workout?.title, 'Fractionné 10 min');

        liveSession.dispose();
        voiceCoach.dispose();
      },
    );

    test(
      'Adopte la durée exacte de la console si la trame ff 0e arrive après le premier coup de rame',
      () async {
        SharedPreferences.setMockInitialValues({});
        final appState = AppStateService();
        await appState.init();

        final fakeBle = _FakeBleService();
        final voiceCoach = VoiceCoachService();
        final liveSession = LiveSessionService(
          appState: appState,
          bleService: fakeBle,
          voiceCoach: voiceCoach,
        );

        // 1. Trame ff 11 / 00 12 arrive en premier (elapsedSeconds encore à 0)
        fakeBle.pushTelemetry(
          isConnected: true,
          telemetry: const RowerTelemetry(
            distanceMeters: 420.0,
            strokesCount: 34,
            elapsedSeconds: 0,
            powerWatts: 140,
            cadenceSpm: 25,
            speedKmh: 12.0,
            resistanceLevel: 8,
          ),
        );
        expect(liveSession.isRunning, isTrue);
        expect(liveSession.sessionElapsedSeconds, 0);

        // 2. Trame ff 0e arrive juste après avec la durée réelle de la console (185s)
        fakeBle.pushTelemetry(
          isConnected: true,
          telemetry: const RowerTelemetry(
            distanceMeters: 425.0,
            strokesCount: 35,
            elapsedSeconds: 185,
            powerWatts: 140,
            cadenceSpm: 25,
            speedKmh: 12.0,
            resistanceLevel: 8,
          ),
        );
        expect(liveSession.sessionElapsedSeconds, 185);
        expect(liveSession.sessionDistanceMeters, 425.0);
        expect(liveSession.sessionStrokesCount, 35);
        expect(liveSession.sessionCalories, greaterThan(25.0));

        liveSession.dispose();
        voiceCoach.dispose();
      },
    );
  });
}

class _FakeBleService extends ProFormBleService {
  bool _connected = false;
  RowerTelemetry _tel = RowerTelemetry();

  @override
  bool get isHardwareConnected => _connected;

  @override
  RowerTelemetry get latestTelemetry => _tel;

  @override
  void setLiveSessionActive(bool active) {}

  void pushTelemetry({
    required bool isConnected,
    required RowerTelemetry telemetry,
  }) {
    _connected = isConnected;
    _tel = telemetry;
    notifyListeners();
  }
}

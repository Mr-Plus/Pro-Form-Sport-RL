import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'app_state_service.dart';
import 'proform_ble_service.dart';
import 'voice_coach_service.dart';

/// Résumé calculé à l'arrêt d'une séance pour affichage et sauvegarde.
class LiveSessionSummary {
  final DateTime startedAt;
  final int durationSeconds;
  final double distanceMeters;
  final int strokesCount;
  final double caloriesKcal;
  final double avgWatts;
  final int maxWatts;
  final double avgSpm;
  final double avgResistance;
  final Workout? workout;
  final List<SessionSample> samples;

  const LiveSessionSummary({
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.strokesCount,
    required this.caloriesKcal,
    required this.avgWatts,
    required this.maxWatts,
    required this.avgSpm,
    required this.avgResistance,
    required this.workout,
    required this.samples,
  });

  RowingSession toWorkoutSession(String userId) {
    return RowingSession(
      id: 'sess_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      workoutId: workout?.id,
      workoutTitle: workout?.title ?? 'Session Libre',
      startedAt: startedAt,
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
      avgWatts: avgWatts,
      maxWatts: maxWatts,
      avgCadenceSpm: avgSpm,
      avgResistance: avgResistance,
      caloriesKcal: caloriesKcal,
      strokesCount: strokesCount,
      source: SessionSource.liveBle,
      samples: List.of(samples),
    );
  }
}

/// Contrôleur centralisé de la séance en cours (Portrait & Paysage).
/// Démarre automatiquement dès le premier coup de rame en Bluetooth,
/// adopte directement les métriques réelles du rameur et enregistre en arrière-plan.
class LiveSessionService extends ChangeNotifier {
  final AppStateService appState;
  final ProFormBleService bleService;
  final VoiceCoachService voiceCoach;

  Timer? _sessionTimer;
  bool _isRunning = false;
  bool _isPaused = false;
  int _inactivitySeconds = 0;
  int _pauseElapsedSeconds = 0;

  int _sessionElapsedSeconds = 0;
  double _sessionDistanceMeters = 0.0;
  int _sessionStrokesCount = 0;
  double _sessionCalories = 0.0;
  double _strokesAccumulator = 0.0;

  int _currentStepIndex = 0;
  int _stepElapsedSeconds = 0;
  DateTime? _startedAt;
  Workout? _selectedWorkout;

  final List<SessionSample> _recordedSamples = [];

  LiveSessionService({
    required this.appState,
    required this.bleService,
    required this.voiceCoach,
  }) {
    bleService.addListener(_onBleTelemetryChanged);
  }

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  int get inactivitySeconds => _inactivitySeconds;
  int get pauseElapsedSeconds => _pauseElapsedSeconds;
  int get sessionElapsedSeconds => _sessionElapsedSeconds;
  double get sessionDistanceMeters => _sessionDistanceMeters;
  int get sessionStrokesCount => _sessionStrokesCount;
  double get sessionCalories => _sessionCalories;
  int get currentStepIndex => _currentStepIndex;
  int get stepElapsedSeconds => _stepElapsedSeconds;
  DateTime? get startedAt => _startedAt;
  Workout? get selectedWorkout => _selectedWorkout;
  List<SessionSample> get recordedSamples => List.unmodifiable(_recordedSamples);

  void selectWorkout(Workout? workout) {
    _selectedWorkout = workout;
    notifyListeners();
  }

  void clearWorkout() {
    _selectedWorkout = null;
    notifyListeners();
  }

  void _onBleTelemetryChanged() {
    final tel = bleService.latestTelemetry;
    final isRowingActive = tel.cadenceSpm > 0 || tel.watts > 5;

    // Auto-démarrage dès le premier coup de rame (même en mode Portrait / tableau de bord)
    if (!_isRunning && bleService.isHardwareConnected && isRowingActive) {
      startSession(auto: true);
      return;
    }

    if (_isRunning) {
      if (_isPaused) {
        if (!tel.isConsolePaused && isRowingActive) {
          resumeSession(auto: true);
        }
      } else {
        if (tel.isConsolePaused) {
          pauseSession(auto: true);
        } else if (_syncFromTelemetry(tel)) {
          notifyListeners();
        }
      }
    }
  }

  /// Synchronise la durée, la distance et les coups avec les valeurs réelles de la console
  /// (utile notamment lorsque la trame 01 12 arrive juste après l'auto-démarrage).
  bool _syncFromTelemetry(RowerTelemetry tel) {
    bool changed = false;
    if (tel.distanceMeters > _sessionDistanceMeters &&
        tel.distanceMeters < 60000) {
      _sessionDistanceMeters = tel.distanceMeters;
      changed = true;
    }
    if (tel.strokesCount > _sessionStrokesCount && tel.strokesCount < 60000) {
      _sessionStrokesCount = tel.strokesCount;
      changed = true;
    }
    if (tel.elapsedSeconds > _sessionElapsedSeconds &&
        tel.elapsedSeconds < 60000) {
      final deltaSec = tel.elapsedSeconds - _sessionElapsedSeconds;
      _sessionElapsedSeconds = tel.elapsedSeconds;
      _startedAt =
          DateTime.now().subtract(Duration(seconds: _sessionElapsedSeconds));
      // Si la durée saute de > 2s (reprise d'une séance déjà commencée avant connexion),
      // on calcule aussi les calories pour la partie déjà ramée de la séance.
      if (deltaSec > 2) {
        _backfillPreConnectionCalories(tel, deltaSec);
      }
      changed = true;
    }
    return changed;
  }

  void _backfillPreConnectionCalories(RowerTelemetry tel, int durationSec) {
    if (durationSec <= 0) return;
    double watts = tel.watts.toDouble();
    if (watts <= 0 && _sessionDistanceMeters > 0 && _sessionElapsedSeconds > 0) {
      final speedMps = _sessionDistanceMeters / _sessionElapsedSeconds;
      watts = (2.80 * speedMps * speedMps * speedMps).clamp(20.0, 600.0);
    }
    if (watts <= 0) watts = 100.0;
    _sessionCalories += appState.activeUser.computeCaloriesForDuration(
      avgWatts: watts,
      durationSeconds: durationSec,
    );
  }

  void startSession({bool auto = false}) {
    if (_isRunning) return;
    _isRunning = true;
    _isPaused = false;
    _inactivitySeconds = 0;
    _pauseElapsedSeconds = 0;
    _currentStepIndex = 0;
    _stepElapsedSeconds = 0;
    _strokesAccumulator = 0.0;
    _sessionCalories = 0.0;
    _recordedSamples.clear();

    bleService.setLiveSessionActive(true);
    final tel = bleService.latestTelemetry;

    // Adopte directement les valeurs réelles déjà présentes sur la console du rameur
    _sessionDistanceMeters =
        (tel.distanceMeters > 0 && tel.distanceMeters < 60000)
            ? tel.distanceMeters
            : 0.0;
    _sessionStrokesCount =
        (tel.strokesCount > 0 && tel.strokesCount < 60000)
            ? tel.strokesCount
            : 0;
    _sessionElapsedSeconds =
        (tel.elapsedSeconds > 0 && tel.elapsedSeconds < 60000)
            ? tel.elapsedSeconds
            : 0;
    _startedAt = DateTime.now().subtract(Duration(seconds: _sessionElapsedSeconds));
    if (_sessionElapsedSeconds > 0) {
      _backfillPreConnectionCalories(tel, _sessionElapsedSeconds);
    }

    final wk = _selectedWorkout;
    if (wk != null && wk.steps.isNotEmpty) {
      final firstStep = wk.steps.first;
      bleService.setResistanceLevel(
        firstStep.targetResistance,
        reason: 'Début séance: ${firstStep.title}',
      );
      voiceCoach.onSessionStarted(
        user: appState.activeUser,
        workout: wk,
      );
    } else {
      voiceCoach.onSessionStarted(
        user: appState.activeUser,
        workout: null,
      );
    }

    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _onTick(),
    );
    notifyListeners();
  }

  void pauseSession({bool auto = false}) {
    if (_isPaused || !_isRunning) return;
    _isPaused = true;
    _inactivitySeconds = 0;
    _pauseElapsedSeconds = 0;
    notifyListeners();

    voiceCoach.speak(
      auto ? 'Rameur en pause.' : 'Séance en pause.',
      type: CoachMessageType.info,
      force: true,
    );
  }

  void resumeSession({bool auto = false}) {
    if (!_isPaused || !_isRunning) return;
    _isPaused = false;
    _inactivitySeconds = 0;
    _pauseElapsedSeconds = 0;
    notifyListeners();

    voiceCoach.speak(
      auto ? 'Reprise de la séance !' : 'Séance reprise.',
      type: CoachMessageType.motivation,
      force: true,
    );
  }

  void togglePause() {
    if (_isPaused) {
      resumeSession(auto: false);
    } else {
      pauseSession(auto: false);
    }
  }

  void _onTick() {
    final tel = bleService.latestTelemetry;
    final user = appState.activeUser;
    final wk = _selectedWorkout;
    final isRowingActive = tel.cadenceSpm > 0 || tel.watts > 5;

    if (!isRowingActive) {
      _inactivitySeconds++;
      if (_inactivitySeconds >= 3 && !_isPaused && _isRunning) {
        pauseSession(auto: true);
        return;
      }
    } else {
      _inactivitySeconds = 0;
      if (_isPaused) {
        resumeSession(auto: true);
        return;
      }
    }

    if (!_isRunning) return;

    if (_isPaused) {
      _pauseElapsedSeconds++;
      notifyListeners();
      return;
    }

    _sessionElapsedSeconds++;
    _stepElapsedSeconds++;

    // Synchronise distance, coups et durée réelle du rameur (ex: ff 0e arrivée après coup)
    _syncFromTelemetry(tel);
    if (tel.strokesCount <= 0 && tel.cadenceSpm > 0) {
      _strokesAccumulator += (tel.cadenceSpm / 60.0);
      _sessionStrokesCount =
          max(_sessionStrokesCount, _strokesAccumulator.floor());
    }

    // Calories calculées depuis les Watts et le poids de l'utilisateur
    if (tel.watts > 0) {
      _sessionCalories +=
          (((0.048 * tel.watts + 1.19) * user.weightKg * 3.5) / 200.0) *
              (1.0 / 60.0);
    }

    _recordedSamples.add(
      SessionSample(
        elapsedSeconds: _sessionElapsedSeconds,
        watts: tel.watts,
        cadenceSpm: tel.cadenceSpm,
        resistance: tel.resistanceLevel,
        distanceMeters: _sessionDistanceMeters,
        speedKmh: tel.speedKmh,
        heartRateBpm: tel.heartRateBpm,
      ),
    );

    if (wk != null && wk.steps.isNotEmpty) {
      final currentStep = wk.steps[_currentStepIndex];
      final nextStep = _currentStepIndex + 1 < wk.steps.length
          ? wk.steps[_currentStepIndex + 1]
          : null;
      final remaining = currentStep.durationSeconds - _stepElapsedSeconds;

      if (_stepElapsedSeconds >= currentStep.durationSeconds) {
        if (_currentStepIndex + 1 < wk.steps.length) {
          _currentStepIndex++;
          _stepElapsedSeconds = 0;
          final newStep = wk.steps[_currentStepIndex];
          bleService.setResistanceLevel(
            newStep.targetResistance,
            reason: 'Bloc ${_currentStepIndex + 1}: ${newStep.title}',
          );
          voiceCoach.onStepChanged(
            user: user,
            newStep: newStep,
            stepIndex: _currentStepIndex,
            totalSteps: wk.steps.length,
          );
          notifyListeners();
        } else {
          notifyListeners();
          // La fin automatique de séance est gérée par l'UI si affichée, sinon reste prête à sauvegarder
        }
        return;
      }

      voiceCoach.evaluateTick(
        user: user,
        telemetry: tel,
        sessionElapsedSec: _sessionElapsedSeconds,
        sessionDistanceMeters: _sessionDistanceMeters,
        samples: _recordedSamples,
        workout: wk,
        currentStep: currentStep,
        nextStep: nextStep,
        stepElapsedSec: _stepElapsedSeconds,
        stepRemainingSec: max(0, remaining),
      );
    } else {
      voiceCoach.evaluateTick(
        user: user,
        telemetry: tel,
        sessionElapsedSec: _sessionElapsedSeconds,
        sessionDistanceMeters: _sessionDistanceMeters,
        samples: _recordedSamples,
        workout: null,
        currentStep: null,
        nextStep: null,
        stepElapsedSec: _sessionElapsedSeconds,
        stepRemainingSec: 0,
      );
    }

    notifyListeners();
  }

  LiveSessionSummary? stopAndBuildSummary() {
    _sessionTimer?.cancel();
    bleService.setLiveSessionActive(false);
    _isRunning = false;
    _isPaused = false;
    notifyListeners();

    if (_sessionElapsedSeconds < 3) return null;

    final tel = bleService.latestTelemetry;
    final avgWatts = _recordedSamples.isEmpty
        ? tel.watts.toDouble()
        : _recordedSamples.map((s) => s.watts).reduce((a, b) => a + b) /
            _recordedSamples.length;
    final maxWatts = _recordedSamples.isEmpty
        ? tel.watts
        : _recordedSamples.map((s) => s.watts).reduce(max);
    final avgSpm = _recordedSamples.isEmpty
        ? tel.cadenceSpm.toDouble()
        : _recordedSamples.map((s) => s.cadenceSpm).reduce((a, b) => a + b) /
            _recordedSamples.length;
    final avgRes = _recordedSamples.isEmpty
        ? tel.resistanceLevel.toDouble()
        : _recordedSamples.map((s) => s.resistance).reduce((a, b) => a + b) /
            _recordedSamples.length;

    voiceCoach.onSessionFinished(
      user: appState.activeUser,
      distanceMeters: _sessionDistanceMeters,
      avgWatts: avgWatts,
      elapsedSeconds: _sessionElapsedSeconds,
    );

    final user = appState.activeUser;
    final kcal = _sessionCalories > 0
        ? _sessionCalories
        : user.computeCaloriesForDuration(
            avgWatts: avgWatts,
            durationSeconds: _sessionElapsedSeconds,
          );

    return LiveSessionSummary(
      startedAt: _startedAt ??
          DateTime.now().subtract(Duration(seconds: _sessionElapsedSeconds)),
      durationSeconds: _sessionElapsedSeconds,
      distanceMeters: _sessionDistanceMeters,
      strokesCount: _sessionStrokesCount,
      caloriesKcal: kcal,
      avgWatts: avgWatts,
      maxWatts: maxWatts,
      avgSpm: avgSpm,
      avgResistance: avgRes,
      workout: _selectedWorkout,
      samples: List<SessionSample>.from(_recordedSamples),
    );
  }

  void resetAfterSaveOrDiscard() {
    _sessionElapsedSeconds = 0;
    _sessionDistanceMeters = 0.0;
    _sessionStrokesCount = 0;
    _sessionCalories = 0.0;
    _strokesAccumulator = 0.0;
    _recordedSamples.clear();
    _startedAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    bleService.removeListener(_onBleTelemetryChanged);
    _sessionTimer?.cancel();
    super.dispose();
  }
}

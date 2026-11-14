import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/models.dart';

enum CoachMessageType {
  info,
  transitionWarning,
  slumpAlert,
  praise,
  motivation,
}

class VoiceCoachService extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isEnabled = true;
  bool get isEnabled => _isEnabled;

  String _lastMessage =
      'Coach vocal punchy prêt • Basculez en mode paysage et envoyez tout !';
  String get lastMessage => _lastMessage;

  CoachMessageType _lastMessageType = CoachMessageType.info;
  CoachMessageType get lastMessageType => _lastMessageType;

  DateTime _lastFeedbackTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _lowCadenceStreakSec = 0;
  int _highCadenceStreakSec = 0;
  int _lowPowerStreakSec = 0;
  int _stoppedStreakSec = 0;
  int _onTargetStreakSec = 0;
  int _lastMilestoneHalfKm = 0;
  int _lastSummaryFiveMin = 0;
  bool _halfwayAnnounced = false;
  bool _workoutCompletedAnnounced = false;
  int _motivationVariant = 0;
  int _nameCalloutCount = 0;

  /// Détermine si l'on cite le prénom ou pseudo de l'utilisateur.
  /// On le cite en début et fin de séance, et seulement environ 1 fois sur 4
  /// lors des encouragements en cours d'effort pour un rendu naturel et non répétitif.
  bool _shouldUseName({bool force = false}) {
    if (force) return true;
    _nameCalloutCount++;
    return (_nameCalloutCount % 4) == 1;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      await _tts.setLanguage('fr-FR');
      // Débit plus rapide (0.60) et timbre plus énergique (1.08) pour une voix punchy !
      await _tts.setSpeechRate(0.60);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.08);
      await _tts.awaitSpeakCompletion(false);
    } catch (e) {
      debugPrint('VoiceCoachService TTS init fallback: $e');
    }
  }

  void toggleEnabled() {
    _isEnabled = !_isEnabled;
    if (!_isEnabled) {
      try {
        _tts.stop();
      } catch (_) {}
    } else {
      speak(
        'Coach vocal activé ! Prêt à tout donner !',
        type: CoachMessageType.info,
        force: true,
      );
    }
    notifyListeners();
  }

  void resetSessionState() {
    _lowCadenceStreakSec = 0;
    _highCadenceStreakSec = 0;
    _lowPowerStreakSec = 0;
    _stoppedStreakSec = 0;
    _onTargetStreakSec = 0;
    _lastMilestoneHalfKm = 0;
    _lastSummaryFiveMin = 0;
    _halfwayAnnounced = false;
    _workoutCompletedAnnounced = false;
    _nameCalloutCount = 0;
    _lastFeedbackTime = DateTime.now();
  }

  Future<void> speak(
    String text, {
    CoachMessageType type = CoachMessageType.info,
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force && now.difference(_lastFeedbackTime).inSeconds < 12) {
      return;
    }
    _lastFeedbackTime = now;
    _lastMessage = text;
    _lastMessageType = type;
    notifyListeners();

    if (!_isEnabled) return;
    try {
      await init();
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('VoiceCoachService speak fallback: $e');
    }
  }

  void onSessionStarted({
    required UserProfile user,
    required Workout? workout,
  }) {
    resetSessionState();
    if (workout != null && workout.steps.isNotEmpty) {
      final first = workout.steps.first;
      speak(
        "Allez ${user.name}, c'est parti pour ${workout.title} ! Premier bloc : ${first.title}, résistance ${first.targetResistance}, cadence ${first.targetSpmMin} à ${first.targetSpmMax} ! Envoie dès maintenant !",
        type: CoachMessageType.motivation,
        force: true,
      );
    } else {
      speak(
        "C'est parti ${user.name} ! Attaque franche, dos gainé, explose les jambes !",
        type: CoachMessageType.motivation,
        force: true,
      );
    }
  }

  void onStepChanged({
    required UserProfile user,
    required WorkoutStep newStep,
    required int stepIndex,
    required int totalSteps,
  }) {
    _lowCadenceStreakSec = 0;
    _highCadenceStreakSec = 0;
    _lowPowerStreakSec = 0;
    _stoppedStreakSec = 0;
    _onTargetStreakSec = 0;

    final durStr = newStep.durationSeconds >= 60
        ? '${newStep.durationSeconds ~/ 60} minute${newStep.durationSeconds >= 120 ? "s" : ""}'
        : '${newStep.durationSeconds} secondes';

    final nameTag = _shouldUseName() ? ' ${user.name}' : '';

    switch (newStep.type) {
      case StepType.warmup:
        speak(
          'Bloc ${stepIndex + 1} sur $totalSteps : ${newStep.title}, $durStr ! Résistance ${newStep.targetResistance}, cadence ${newStep.targetSpmMin} à ${newStep.targetSpmMax}. Mets du rythme !',
          type: CoachMessageType.info,
          force: true,
        );
      case StepType.work:
        speak(
          "GO$nameTag ! ${newStep.title} pendant $durStr ! Résistance ${newStep.targetResistance}, attaque à ${newStep.targetSpmMin}-${newStep.targetSpmMax} coups minute. Explose tout !",
          type: CoachMessageType.motivation,
          force: true,
        );
      case StepType.rest:
        speak(
          'Solide$nameTag ! $durStr de récup active à résistance ${newStep.targetResistance}. Respire fort, on repart bientôt au combat !',
          type: CoachMessageType.praise,
          force: true,
        );
      case StepType.cooldown:
        speak(
          'Énorme séance$nameTag ! Retour au calme pendant $durStr à résistance ${newStep.targetResistance}. Relâche les bras !',
          type: CoachMessageType.praise,
          force: true,
        );
    }
  }

  void onWorkoutCompleted({
    required UserProfile user,
    required double distanceMeters,
    required int elapsedSeconds,
  }) {
    if (_workoutCompletedAnnounced) return;
    _workoutCompletedAnnounced = true;
    speak(
      'Bravo ${user.name}, fin de séance ! Tu as bouclé le programme avec ${distanceMeters.round()} mètres. Tu peux ralentir et t\'arrêter maintenant !',
      type: CoachMessageType.praise,
      force: true,
    );
  }

  void onSessionFinished({
    required UserProfile user,
    required double distanceMeters,
    required double avgWatts,
    required int elapsedSeconds,
  }) {
    if (elapsedSeconds < 5) return;
    speak(
      'Boum ! Séance bouclée ${user.name} ! ${distanceMeters.round()} mètres avalés à ${avgWatts.round()} watts de moyenne ! Quelle performance !',
      type: CoachMessageType.praise,
      force: true,
    );
  }

  /// Appelé chaque seconde pendant la séance pour analyser le rythme, les transitions et les coups de mou
  void evaluateTick({
    required UserProfile user,
    required RowerTelemetry telemetry,
    required int sessionElapsedSec,
    required double sessionDistanceMeters,
    required List<SessionSample> samples,
    required Workout? workout,
    required WorkoutStep? currentStep,
    required WorkoutStep? nextStep,
    required int stepElapsedSec,
    required int stepRemainingSec,
  }) {
    if (_workoutCompletedAnnounced) return;

    // 1. Avertissement de changement de rythme imminent (Priorité Haute)
    if (currentStep != null) {
      if (stepRemainingSec == 10 && currentStep.durationSeconds >= 20) {
        if (nextStep != null) {
          if (nextStep.type == StepType.work) {
            final nameTag = _shouldUseName() ? ' ${user.name}' : '';
            speak(
              'Attention$nameTag, impact dans 10 secondes ! Prochain bloc : ${nextStep.title}, résistance ${nextStep.targetResistance}, cible ${nextStep.targetSpmMin}-${nextStep.targetSpmMax} SPM. Prêt à exploser !',
              type: CoachMessageType.transitionWarning,
              force: true,
            );
          } else {
            speak(
              'Plus que 10 secondes d\'effort ! Lâche rien jusqu\'au bout, la récup arrive à résistance ${nextStep.targetResistance} !',
              type: CoachMessageType.transitionWarning,
              force: true,
            );
          }
        } else {
          final nameTag = _shouldUseName() ? ' ${user.name}' : '';
          if (currentStep.type == StepType.rest ||
              currentStep.type == StepType.cooldown) {
            speak(
              'Plus que 10 secondes de récupération$nameTag, relâche doucement, la séance est presque terminée !',
              type: CoachMessageType.praise,
              force: true,
            );
          } else {
            speak(
              'Dernières 10 secondes$nameTag ! Sprint final, vide le réservoir maintenant !',
              type: CoachMessageType.transitionWarning,
              force: true,
            );
          }
        }
        return;
      }

      if (stepRemainingSec == 3 &&
          currentStep.durationSeconds >= 15 &&
          nextStep != null &&
          nextStep.type == StepType.work) {
        speak(
          '3, 2, 1, ENVOYEZ !',
          type: CoachMessageType.transitionWarning,
          force: true,
        );
        return;
      }
    }

    // 2. Résumé périodique toutes les 5 minutes (où on en est + temps restant)
    final fiveMinIndex = sessionElapsedSec ~/ 300;
    if (fiveMinIndex > _lastSummaryFiveMin && sessionElapsedSec >= 300) {
      _lastSummaryFiveMin = fiveMinIndex;
      final elapsedMin = fiveMinIndex * 5;
      final distMeters = sessionDistanceMeters.round();
      final nameTag = _shouldUseName() ? ' ${user.name}' : '';
      if (workout != null) {
        final totalSec = workout.totalDurationSeconds;
        final remSec = (totalSec - sessionElapsedSec).clamp(0, totalSec);
        final String remText;
        if (remSec >= 60) {
          final rm = remSec ~/ 60;
          final rs = remSec % 60;
          remText = rs > 0
              ? '$rm minute${rm > 1 ? "s" : ""} et $rs secondes'
              : '$rm minute${rm > 1 ? "s" : ""}';
        } else if (remSec > 0) {
          remText = '$remSec secondes';
        } else {
          remText = 'quelques secondes';
        }
        speak(
          'Point à $elapsedMin minutes$nameTag : $distMeters mètres parcourus, allure ${telemetry.formattedSplit500m} au 500. Il reste $remText, continue comme ça !',
          type: CoachMessageType.info,
          force: true,
        );
      } else {
        speak(
          'Point à $elapsedMin minutes$nameTag : $distMeters mètres parcourus, allure ${telemetry.formattedSplit500m} au 500. Beau rythme, lâche rien !',
          type: CoachMessageType.info,
          force: true,
        );
      }
      return;
    }

    // 3. Félicitations aux caps de distance tous les 500 mètres
    final halfKmIndex = (sessionDistanceMeters ~/ 500);
    if (halfKmIndex > _lastMilestoneHalfKm && sessionDistanceMeters >= 500) {
      _lastMilestoneHalfKm = halfKmIndex;
      final meters = halfKmIndex * 500;
      final nameTag = _shouldUseName() ? ' ${user.name}' : '';
      speak(
        'Boum ! Cap des $meters mètres explosé ! Allure ${telemetry.formattedSplit500m} au 500,$nameTag maintiens la pression !',
        type: CoachMessageType.praise,
        force: true,
      );
      return;
    }

    // 3. Félicitations à mi-parcours d'un entraînement structuré
    if (workout != null &&
        !_halfwayAnnounced &&
        workout.totalDurationSeconds >= 240 &&
        sessionElapsedSec == (workout.totalDurationSeconds ~/ 2)) {
      _halfwayAnnounced = true;
      final nameTag = _shouldUseName() ? ' ${user.name}' : '';
      speak(
        'Mi-parcours franchi$nameTag ! C\'est maintenant qu\'on fait la différence, verrouille les abdos et pousse !',
        type: CoachMessageType.motivation,
        force: true,
      );
      return;
    }

    if (sessionElapsedSec < 10 || (currentStep != null && stepElapsedSec < 10)) {
      return;
    }
    if (currentStep != null && stepRemainingSec <= 12) {
      return;
    }

    final spm = telemetry.cadenceSpm;
    final watts = telemetry.powerWatts;

    // 4. Détection d'arrêt complet pendant un bloc de travail
    final isRestOrCooldown = currentStep?.type == StepType.rest ||
        currentStep?.type == StepType.cooldown;
    if (!isRestOrCooldown && spm < 8 && watts < 15) {
      _stoppedStreakSec++;
      if (_stoppedStreakSec >= 5) {
        _stoppedStreakSec = 0;
        final nameTag = _shouldUseName() ? ' ${user.name}' : '';
        speak(
          'Eh$nameTag, on ne s\'arrête pas ! Arrache cette poignée et relance la roue tout de suite !',
          type: CoachMessageType.slumpAlert,
        );
        return;
      }
    } else {
      _stoppedStreakSec = 0;
    }

    // 5. Analyse pendant un bloc structuré (Fréquence / Cadence, Puissance & Félicitations)
    if (currentStep != null && !isRestOrCooldown) {
      if (spm > 0 && spm < currentStep.targetSpmMin - 2) {
        _lowCadenceStreakSec++;
        _highCadenceStreakSec = 0;
        _onTargetStreakSec = 0;
        if (_lowCadenceStreakSec >= 5) {
          _lowCadenceStreakSec = 0;
          final nameTag = _shouldUseName() ? ' ${user.name}' : '';
          speak(
            'Réveille la cadence$nameTag ! Tu es à $spm SPM, accélère pour rentrer dans la cible ${currentStep.targetSpmMin} à ${currentStep.targetSpmMax} coups minute !',
            type: CoachMessageType.slumpAlert,
          );
          return;
        }
      } else if (spm > currentStep.targetSpmMax + 3) {
        _highCadenceStreakSec++;
        _lowCadenceStreakSec = 0;
        _onTargetStreakSec = 0;
        if (_highCadenceStreakSec >= 6) {
          _highCadenceStreakSec = 0;
          final nameTag = _shouldUseName() ? ' ${user.name}' : '';
          speak(
            'Cadence un peu élevée$nameTag à $spm SPM, cale-toi entre ${currentStep.targetSpmMin} et ${currentStep.targetSpmMax} coups minute !',
            type: CoachMessageType.info,
          );
          return;
        }
      } else {
        _lowCadenceStreakSec = 0;
        _highCadenceStreakSec = 0;
      }

      final targetW = currentStep.targetWatts;
      if (targetW != null && watts > 0 && watts < (targetW * 0.78).round()) {
        _lowPowerStreakSec++;
        _onTargetStreakSec = 0;
        if (_lowPowerStreakSec >= 6) {
          _lowPowerStreakSec = 0;
          final nameTag = _shouldUseName() ? ' ${user.name}' : '';
          speak(
            'Plus de jus$nameTag ! $watts watts seulement, claque les talons et remonte à $targetW watts !',
            type: CoachMessageType.slumpAlert,
          );
          return;
        }
      } else {
        _lowPowerStreakSec = 0;
      }

      final inSpmZone = spm >= currentStep.targetSpmMin &&
          spm <= currentStep.targetSpmMax + 3;
      final inWattsZone =
          targetW == null ? true : watts >= (targetW * 0.92).round();

      if (inSpmZone && inWattsZone) {
        _onTargetStreakSec++;
        if (_onTargetStreakSec >= 15) {
          _onTargetStreakSec = 0;
          _motivationVariant = (_motivationVariant + 1) % 3;
          final nameTag = _shouldUseName() ? ' ${user.name}' : '';
          final msg = switch (_motivationVariant) {
            0 =>
              'Cadence parfaite$nameTag à $spm coups minute, tu es exactement dans la zone ${currentStep.targetSpmMin} à ${currentStep.targetSpmMax} !',
            1 =>
              'Fréquence nickel à $spm SPM et $watts watts, tu respectes parfaitement la consigne !',
            _ =>
              'Tu es pile dans la cadence convenue à $spm coups minute$nameTag, continue comme ça !',
          };
          speak(msg, type: CoachMessageType.praise);
          return;
        }
      }
      return;
    }

    // 6. Analyse en Session Libre
    if (currentStep == null && samples.length >= 25) {
      final recentWindow = samples.sublist(samples.length - 6);
      final baselineWindow =
          samples.sublist(samples.length - 25, samples.length - 6);

      final recentAvgWatts =
          recentWindow.fold<int>(0, (s, e) => s + e.watts) /
              recentWindow.length;
      final baselineAvgWatts =
          baselineWindow.fold<int>(0, (s, e) => s + e.watts) /
              baselineWindow.length;

      if (baselineAvgWatts > 60 &&
          recentAvgWatts > 10 &&
          recentAvgWatts < baselineAvgWatts * 0.72) {
        _lowPowerStreakSec++;
        if (_lowPowerStreakSec >= 5) {
          _lowPowerStreakSec = 0;
          final nameTag = _shouldUseName() ? ' ${user.name}' : '';
          speak(
            'Eh$nameTag, baisse de régime à ${recentAvgWatts.round()} watts ! Relance la machine et repasse au-dessus de ${baselineAvgWatts.round()} watts !',
            type: CoachMessageType.slumpAlert,
          );
          return;
        }
      } else {
        _lowPowerStreakSec = 0;
      }

      if (recentAvgWatts >= baselineAvgWatts * 1.05 && recentAvgWatts >= 100) {
        _onTargetStreakSec++;
        if (_onTargetStreakSec >= 20) {
          _onTargetStreakSec = 0;
          final nameTag = _shouldUseName() ? ' ${user.name}' : '';
          speak(
            'Solide$nameTag ! ${recentAvgWatts.round()} watts à $spm SPM, quel rythme de patron !',
            type: CoachMessageType.praise,
          );
        }
      }
    }
  }
}

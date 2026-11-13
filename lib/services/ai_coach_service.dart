import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class AiCoachService {
  /// Génère une séance concrète à partir d'un des 8 modèles standards,
  /// calibrée selon la durée, la complexité/intensité et le profil utilisateur.
  static Workout buildWorkoutFromTemplate({
    required WorkoutTemplateType template,
    required int durationMinutes,
    required String intensity, // 'douce', 'moderee', 'intense', 'maximale'
    required UserProfile user,
    List<RowingSession> userHistory = const [],
  }) {
    final totalSeconds = (durationMinutes.clamp(5, 120)) * 60;
    final nowMs = DateTime.now().microsecondsSinceEpoch;

    int baseRes = switch (user.level) {
      FitnessLevel.beginner => 6,
      FitnessLevel.intermediate => 10,
      FitnessLevel.advanced => 14,
    };
    if (userHistory.isNotEmpty) {
      final histRes = (userHistory
                  .map((s) => s.avgResistance)
                  .reduce((a, b) => a + b) /
              userHistory.length)
          .round();
      baseRes = ((baseRes + histRes) ~/ 2).clamp(5, 18);
    }

    final intensityBonus = switch (intensity) {
      'douce' => -2,
      'moderee' => 0,
      'intense' => 3,
      'maximale' => 6,
      _ => 0,
    };

    final workRes = (baseRes + intensityBonus).clamp(4, 24);
    final restRes = max(1, min(workRes - 2, 4));
    final warmupRes = max(1, min(workRes - 1, restRes + 1));
    final peakRes = min(24, max(workRes + 3, restRes + 4));

    final baseWatts = switch (user.level) {
      FitnessLevel.beginner => 110,
      FitnessLevel.intermediate => 165,
      FitnessLevel.advanced => 225,
    };

    final warmupSec = (totalSeconds * 0.12).round().clamp(90, 300);
    final cooldownSec = (totalSeconds * 0.10).round().clamp(60, 240);
    final coreSeconds = max(120, totalSeconds - warmupSec - cooldownSec);

    final steps = <WorkoutStep>[
      WorkoutStep(
        id: 'tpl_${nowMs}_wu',
        title: 'Échauffement progressif',
        type: StepType.warmup,
        durationSeconds: warmupSec,
        targetResistance: warmupRes,
        targetSpmMin: 18,
        targetSpmMax: 21,
        targetWatts: (baseWatts * 0.7).round(),
        notes: 'Mise en route souple : jambes, dos, bras.',
      ),
    ];

    switch (template) {
      case WorkoutTemplateType.endurance:
        steps.add(
          WorkoutStep(
            id: 'tpl_${nowMs}_end',
            title: 'Endurance continue (SMR $workRes)',
            type: StepType.work,
            durationSeconds: coreSeconds,
            targetResistance: workRes,
            targetSpmMin: 18,
            targetSpmMax: 22,
            targetWatts: (baseWatts * 0.9).round(),
            notes: 'Allure régulière et respiratoire (ratio 1:2).',
          ),
        );
        break;

      case WorkoutTemplateType.tempo:
        final blocks = coreSeconds >= 900 ? 3 : 2;
        const restSec = 60;
        final workSec = max(180, (coreSeconds - (blocks - 1) * restSec) ~/ blocks);
        for (int i = 1; i <= blocks; i++) {
          steps.add(
            WorkoutStep(
              id: 'tpl_${nowMs}_tmp_w_$i',
              title: 'Bloc Tempo #$i/$blocks (SMR $workRes)',
              type: StepType.work,
              durationSeconds: workSec,
              targetResistance: workRes,
              targetSpmMin: 22,
              targetSpmMax: 26,
              targetWatts: (baseWatts * 1.08).round(),
              notes: 'Rythme soutenu et régulier.',
            ),
          );
          if (i < blocks) {
            steps.add(
              WorkoutStep(
                id: 'tpl_${nowMs}_tmp_r_$i',
                title: 'Récupération #$i',
                type: StepType.rest,
                durationSeconds: restSec,
                targetResistance: restRes,
                targetSpmMin: 18,
                targetSpmMax: 20,
                targetWatts: (baseWatts * 0.55).round(),
              ),
            );
          }
        }
        break;

      case WorkoutTemplateType.longIntervals:
        const workSec = 180;
        const restSec = 90;
        final cycles = (coreSeconds ~/ (workSec + restSec)).clamp(2, 10);
        final liSpmMin = switch (user.level) {
          FitnessLevel.beginner => 22,
          FitnessLevel.intermediate => 24,
          FitnessLevel.advanced => 26,
        };
        final liSpmMax = liSpmMin + 4;
        for (int i = 1; i <= cycles; i++) {
          steps.add(
            WorkoutStep(
              id: 'tpl_${nowMs}_li_w_$i',
              title: 'Intervalle long #$i/$cycles (SMR $workRes)',
              type: StepType.work,
              durationSeconds: workSec,
              targetResistance: workRes,
              targetSpmMin: liSpmMin,
              targetSpmMax: liSpmMax,
              targetWatts: (baseWatts * 1.2).round(),
              notes: 'Effort soutenu constant sur 3 min.',
            ),
          );
          steps.add(
            WorkoutStep(
              id: 'tpl_${nowMs}_li_r_$i',
              title: 'Récupération active #$i',
              type: StepType.rest,
              durationSeconds: restSec,
              targetResistance: restRes,
              targetSpmMin: 18,
              targetSpmMax: 21,
              targetWatts: (baseWatts * 0.55).round(),
            ),
          );
        }
        break;

      case WorkoutTemplateType.hiit:
        const workSec = 30;
        const restSec = 30;
        final cycles = (coreSeconds ~/ (workSec + restSec)).clamp(4, 30);
        final hiitSpmMin = switch (user.level) {
          FitnessLevel.beginner => 24,
          FitnessLevel.intermediate => 26,
          FitnessLevel.advanced => 28,
        };
        final hiitSpmMax = switch (user.level) {
          FitnessLevel.beginner => 28,
          FitnessLevel.intermediate => 30,
          FitnessLevel.advanced => 34,
        };
        for (int i = 1; i <= cycles; i++) {
          final r = (i % 3 == 0 ? peakRes : workRes).clamp(restRes + 2, 24);
          steps.add(
            WorkoutStep(
              id: 'tpl_${nowMs}_hiit_w_$i',
              title: 'Sprint 30s #$i/$cycles (SMR $r)',
              type: StepType.work,
              durationSeconds: workSec,
              targetResistance: r,
              targetSpmMin: hiitSpmMin,
              targetSpmMax: hiitSpmMax,
              targetWatts: (baseWatts * 1.35).round(),
              notes: 'Poussée dynamique des jambes sans crisper le dos.',
            ),
          );
          steps.add(
            WorkoutStep(
              id: 'tpl_${nowMs}_hiit_r_$i',
              title: 'Récupération 30s #$i',
              type: StepType.rest,
              durationSeconds: restSec,
              targetResistance: restRes,
              targetSpmMin: 18,
              targetSpmMax: 21,
              targetWatts: (baseWatts * 0.5).round(),
            ),
          );
        }
        break;

      case WorkoutTemplateType.pyramid:
        final resLevels = [
          max(restRes + 1, workRes - 2),
          workRes,
          peakRes,
          workRes,
          max(restRes + 1, workRes - 2),
        ];
        final spmLevels = user.level == FitnessLevel.beginner
            ? [20, 22, 23, 22, 20]
            : [22, 24, 26, 24, 22];
        final blockSec = (coreSeconds ~/ resLevels.length).clamp(60, 600);
        for (int i = 0; i < resLevels.length; i++) {
          final r = resLevels[i].clamp(1, 24);
          steps.add(
            WorkoutStep(
              id: 'tpl_${nowMs}_pyr_$i',
              title: i == 2
                  ? 'Sommet Pyramide (SMR $r)'
                  : 'Palier Pyramide ${i + 1}/5 (SMR $r)',
              type: StepType.work,
              durationSeconds: blockSec,
              targetResistance: r,
              targetSpmMin: spmLevels[i] - 1,
              targetSpmMax: spmLevels[i] + 1,
              targetWatts: (baseWatts * (0.95 + (i == 2 ? 0.35 : 0.1))).round(),
            ),
          );
        }
        break;

      case WorkoutTemplateType.strength:
        final strongRes = switch (user.level) {
          FitnessLevel.beginner => min(13, max(workRes + 2, 10)),
          FitnessLevel.intermediate => min(18, max(workRes + 3, 12)),
          FitnessLevel.advanced => min(24, max(workRes + 3, 15)),
        };
        const workSec = 120;
        const restSec = 60;
        final cycles = (coreSeconds ~/ (workSec + restSec)).clamp(2, 12);
        for (int i = 1; i <= cycles; i++) {
          steps.add(
            WorkoutStep(
              id: 'tpl_${nowMs}_str_w_$i',
              title: 'Force basse cadence #$i/$cycles (SMR $strongRes)',
              type: StepType.work,
              durationSeconds: workSec,
              targetResistance: strongRes,
              targetSpmMin: 16,
              targetSpmMax: 20,
              targetWatts: (baseWatts * 1.25).round(),
              notes: 'Cadence lente, poussée maximale des jambes.',
            ),
          );
          steps.add(
            WorkoutStep(
              id: 'tpl_${nowMs}_str_r_$i',
              title: 'Relâchement #$i',
              type: StepType.rest,
              durationSeconds: restSec,
              targetResistance: restRes,
              targetSpmMin: 18,
              targetSpmMax: 20,
              targetWatts: (baseWatts * 0.55).round(),
            ),
          );
        }
        break;

      case WorkoutTemplateType.timeTrial:
        steps.add(
          WorkoutStep(
            id: 'tpl_${nowMs}_tt',
            title: 'Contre-la-montre $durationMinutes min (SMR $workRes)',
            type: StepType.work,
            durationSeconds: coreSeconds,
            targetResistance: workRes,
            targetSpmMin: 26,
            targetSpmMax: 32,
            targetWatts: (baseWatts * 1.25).round(),
            notes: 'Effort maximal continu : cherchez le meilleur rythme !',
          ),
        );
        break;

      case WorkoutTemplateType.recovery:
        final softRes = max(2, min(6, workRes - 3));
        steps.add(
          WorkoutStep(
            id: 'tpl_${nowMs}_rec',
            title: 'Récupération & Technique (SMR $softRes)',
            type: StepType.work,
            durationSeconds: coreSeconds,
            targetResistance: softRes,
            targetSpmMin: 16,
            targetSpmMax: 20,
            targetWatts: (baseWatts * 0.65).round(),
            notes: 'Concentrez-vous sur le geste : jambes → dos → bras.',
          ),
        );
        break;
    }

    steps.add(
      WorkoutStep(
        id: 'tpl_${nowMs}_cd',
        title: 'Retour au calme',
        type: StepType.cooldown,
        durationSeconds: cooldownSec,
        targetResistance: max(1, restRes - 1),
        targetSpmMin: 16,
        targetSpmMax: 19,
        targetWatts: (baseWatts * 0.5).round(),
      ),
    );

    final intensityLabel = switch (intensity) {
      'douce' => 'Douce',
      'moderee' => 'Modérée',
      'intense' => 'Intense',
      'maximale' => 'Maximale',
      _ => 'Modérée',
    };

    final raw = Workout(
      id: 'wk_${template.name}_$nowMs',
      title: '${template.label} ($intensityLabel)',
      description: '${template.subtitle} • $durationMinutes min',
      category: template.name,
      createdByUserId: user.id,
      isAiGenerated: false,
      steps: steps,
      createdAt: DateTime.now(),
    );

    return _validateAndSanitizeWorkout(raw);
  }

  /// Génère une séance d'entraînement personnalisée via l'API Gemini (si clé fournie)
  /// ou via le moteur d'intelligence embarqué calibré sur le profil et l'historique.
  static Future<Workout> generateCustomWorkout({
    required UserProfile user,
    required List<RowingSession> userHistory,
    required int durationMinutes,
    required String focusPrompt,
    required String intensity, // 'douce', 'moderee', 'intense', 'maximale'
    String? geminiApiKey,
  }) async {
    if (geminiApiKey != null && geminiApiKey.trim().isNotEmpty) {
      try {
        return await _generateWithGeminiApi(
          apiKey: geminiApiKey.trim(),
          user: user,
          userHistory: userHistory,
          durationMinutes: durationMinutes,
          focusPrompt: focusPrompt,
          intensity: intensity,
        );
      } catch (_) {
        // Repli transparent sur le moteur intelligent embarqué
      }
    }

    return _generateSmartLocalWorkout(
      user: user,
      userHistory: userHistory,
      durationMinutes: durationMinutes,
      focusPrompt: focusPrompt,
      intensity: intensity,
    );
  }

  /// Génère un programme complet sur plusieurs semaines adapté au profil utilisateur
  static Future<TrainingProgram> generateTrainingProgram({
    required UserProfile user,
    required List<RowingSession> userHistory,
    required int weeksCount,
    required int sessionsPerWeek,
    required int avgSessionMinutes,
    required String objectivePrompt,
    WorkoutGoal? goal,
    List<int>? trainingDays,
    String trainingTime = '18:30',
    bool notificationsEnabled = true,
    bool isAiGenerated = true,
    String? geminiApiKey,
  }) async {
    final effectiveGoal = goal ?? user.goal;
    final workouts = <Workout>[];
    final totalSessions = weeksCount * sessionsPerWeek;

    final defaultDays = switch (sessionsPerWeek) {
      1 => [3],
      2 => [2, 5],
      3 => [1, 3, 5],
      4 => [1, 2, 4, 6],
      5 => [1, 2, 3, 5, 6],
      6 => [1, 2, 3, 4, 5, 6],
      _ => [1, 2, 3, 4, 5, 6, 7],
    };
    final effectiveDays =
        (trainingDays != null && trainingDays.isNotEmpty)
            ? (List<int>.from(trainingDays)..sort())
            : defaultDays;

    for (int w = 1; w <= weeksCount; w++) {
      for (int s = 1; s <= sessionsPerWeek; s++) {
        final sessionNumber = (w - 1) * sessionsPerWeek + s;
        String sessionTypeFocus;
        String sessionIntensity;

        if (s == 1) {
          sessionTypeFocus =
              'Semaine $w - Séance $s : Fractionné HIIT & Vitesse ($objectivePrompt)';
          sessionIntensity = w >= 3 ? 'maximale' : 'intense';
        } else if (s == 2) {
          sessionTypeFocus =
              'Semaine $w - Séance $s : Pyramide Force & Résistance SMR ($objectivePrompt)';
          sessionIntensity = 'intense';
        } else if (s == 3) {
          sessionTypeFocus =
              'Semaine $w - Séance $s : Endurance Fondamentale & Rythme ($objectivePrompt)';
          sessionIntensity = 'moderee';
        } else {
          sessionTypeFocus =
              'Semaine $w - Séance $s : Récupération Active & Technique ($objectivePrompt)';
          sessionIntensity = 'douce';
        }

        final workout = _generateSmartLocalWorkout(
          user: user.copyWith(goal: effectiveGoal),
          userHistory: userHistory,
          durationMinutes: avgSessionMinutes + ((w - 1) * 2),
          focusPrompt: sessionTypeFocus,
          intensity: sessionIntensity,
          weekProgressionBonus: w - 1,
          customTitle:
              'S$w.$s • ${s == 1 ? "Fractionné HIIT" : s == 2 ? "Pyramide Force SMR" : s == 3 ? "Endurance Tempo" : "Cardio Technique"} ($sessionNumber/$totalSessions)',
        );
        workouts.add(workout);
      }
    }

    return TrainingProgram(
      id: 'prog_${DateTime.now().millisecondsSinceEpoch}',
      title: objectivePrompt.trim().isNotEmpty
          ? 'Programme : ${objectivePrompt.trim()}'
          : 'Programme ${effectiveGoal.label} ($weeksCount sem.)',
      description:
          'Programme de $weeksCount semaines ($sessionsPerWeek séances/sem à $trainingTime) calibré pour ${user.name} (${user.age} ans, ${user.heightCm} cm, ${user.weightKg.toInt()} kg • objectif ${effectiveGoal.label}).',
      userId: user.id,
      goal: effectiveGoal,
      weeksCount: weeksCount,
      sessionsPerWeek: sessionsPerWeek,
      trainingDays: effectiveDays,
      trainingTime: trainingTime,
      notificationsEnabled: notificationsEnabled,
      isAiGenerated: isAiGenerated,
      workouts: workouts,
      completedWorkoutIds: const [],
      createdAt: DateTime.now(),
    );
  }

  static Future<Workout> _generateWithGeminiApi({
    required String apiKey,
    required UserProfile user,
    required List<RowingSession> userHistory,
    required int durationMinutes,
    required String focusPrompt,
    required String intensity,
  }) async {
    final avgHistWatts = userHistory.isEmpty
        ? 140
        : (userHistory.map((s) => s.avgWatts).reduce((a, b) => a + b) /
                userHistory.length)
            .round();

    final systemPrompt = '''
Tu es un préparateur physique expert en aviron indoor sur rameur Pro-Form Sport RL (24 niveaux de résistance magnétique SMR de 1 à 24).
Profil rameur: ${user.name}, ${user.age} ans, ${user.heightCm} cm, ${user.weightKg} kg, Niveau: ${user.level.label}, Objectif: ${user.goal.label}, Puissance moyenne habituelle: ${avgHistWatts}W.
Durée totale souhaitée: $durationMinutes minutes (${durationMinutes * 60} secondes).
Intensité: $intensity.
Demande spécifique: "$focusPrompt".

RÈGLE D'OR PHYSIOLOGIQUE ET BIOMÉCANIQUE ABSOLUE :
- Pour chaque bloc de travail/sprint (type: "work"), la résistance (targetResistance), la cadence (targetSpm) et la puissance (targetWatts) DOIVENT TOUJOURS ÊTRE STRICTEMENT SUPÉRIEURES à celles des blocs de repos/récupération active (type: "rest") et de retour au calme (type: "cooldown").
- Il est STRICTEMENT INTERDIT d'avoir un repos à résistance plus élevée qu'un sprint (ex: sprint à 3 et repos à 5 est une anomalie biomécanique majeure).
- Même pour une séance de "reprise tranquille" avec "un peu de fractionné", la phase de repos doit être très légère (ex: SMR 1 à 3) et le sprint/effort doit être supérieur (ex: SMR 5 à 7).

Réponds UNIQUEMENT avec un objet JSON valide au format:
{
  "title": "Nom motivant de la séance",
  "description": "Explication courte des bénéfices et de la structure",
  "category": "ai",
  "steps": [
    {
      "title": "Nom du bloc",
      "type": "warmup|work|rest|cooldown",
      "durationSeconds": 180,
      "targetResistance": 6,
      "targetSpmMin": 20,
      "targetSpmMax": 24,
      "targetWatts": 130,
      "notes": "Conseil technique"
    }
  ]
}
Assure-toi que targetResistance est compris entre 1 et 24 et que la somme des durationSeconds vaut environ ${durationMinutes * 60} secondes.
''';

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': systemPrompt}
                ]
              }
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'temperature': 0.7,
            },
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Erreur API Gemini (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List<dynamic>?;
    final text = candidates?.first['content']['parts']?.first['text'] as String?;
    if (text == null) throw Exception('Réponse Gemini vide');

    final decoded = jsonDecode(text) as Map<String, dynamic>;
    decoded['id'] = 'ai_${DateTime.now().millisecondsSinceEpoch}';
    decoded['createdByUserId'] = user.id;
    decoded['isAiGenerated'] = true;
    decoded['createdAt'] = DateTime.now().toIso8601String();
    return _validateAndSanitizeWorkout(Workout.fromJson(decoded));
  }

  static Workout _generateSmartLocalWorkout({
    required UserProfile user,
    required List<RowingSession> userHistory,
    required int durationMinutes,
    required String focusPrompt,
    required String intensity,
    int weekProgressionBonus = 0,
    String? customTitle,
  }) {
    final totalSeconds = (durationMinutes.clamp(5, 90)) * 60;
    final promptLower = focusPrompt.toLowerCase();

    int baseRes = switch (user.level) {
      FitnessLevel.beginner => 6,
      FitnessLevel.intermediate => 10,
      FitnessLevel.advanced => 14,
    };

    if (userHistory.isNotEmpty) {
      final histRes = (userHistory
                  .map((s) => s.avgResistance)
                  .reduce((a, b) => a + b) /
              userHistory.length)
          .round();
      baseRes = ((baseRes + histRes) ~/ 2).clamp(5, 18);
    }

    final intensityBonus = switch (intensity) {
      'douce' => -1,
      'moderee' => 0,
      'intense' => 3,
      'maximale' => 5,
      _ => 0,
    };

    // Règle biomécanique stricte :
    // Même en séance douce, workRes >= 5 pour que restRes puisse descendre à 2 ou 3 sans jamais dépasser le sprint.
    final workRes =
        (baseRes + intensityBonus + weekProgressionBonus).clamp(5, 24);
    final restRes = max(1, min(workRes - 2, 4));
    final warmupRes = max(1, min(workRes - 1, restRes + 1));
    final peakRes = max(workRes + 2, restRes + 3);

    final baseWatts = switch (user.level) {
      FitnessLevel.beginner => 110,
      FitnessLevel.intermediate => 165,
      FitnessLevel.advanced => 225,
    };

    final steps = <WorkoutStep>[];
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final warmupSec = (totalSeconds * 0.15).round().clamp(120, 300);
    final cooldownSec = (totalSeconds * 0.12).round().clamp(90, 240);
    final coreSeconds = (totalSeconds - warmupSec - cooldownSec).clamp(180, 5000);

    steps.add(
      WorkoutStep(
        id: 'step_${nowMs}_warmup',
        title: 'Échauffement progressif & mobilité',
        type: StepType.warmup,
        durationSeconds: warmupSec,
        targetResistance: warmupRes,
        targetSpmMin: 18,
        targetSpmMax: 22,
        targetWatts: (baseWatts * 0.7).round(),
        notes: 'Allongez bien le coup de rame : Jambes -> Dos -> Bras.',
      ),
    );

    final isPyramid = promptLower.contains('pyramide') ||
        promptLower.contains('progress') ||
        promptLower.contains('force') ||
        user.goal == WorkoutGoal.powerStrength;
    final isTabataOrShortHiit = promptLower.contains('tabata') ||
        promptLower.contains('30/30') ||
        promptLower.contains('sprint') ||
        promptLower.contains('fractionn') ||
        promptLower.contains('hiit') ||
        promptLower.contains('explos');
    final isEndurance = !isTabataOrShortHiit &&
        (promptLower.contains('endurance') ||
            promptLower.contains('fondamental') ||
            promptLower.contains('douce') ||
            intensity == 'douce' ||
            user.goal == WorkoutGoal.recovery);

    if (isPyramid) {
      final blockCount = 5;
      final blockSec = (coreSeconds ~/ blockCount).clamp(60, 600);
      final pyramidRes = [
        max(restRes + 1, workRes - 2),
        workRes,
        peakRes,
        workRes,
        max(restRes + 1, workRes - 1),
      ];
      final isStrengthFocus =
          user.goal == WorkoutGoal.powerStrength || promptLower.contains('force');
      final pyramidSpm = isStrengthFocus
          ? [16, 18, 20, 18, 16]
          : (user.level == FitnessLevel.beginner
              ? [20, 22, 23, 22, 20]
              : [22, 24, 26, 24, 22]);

      for (int i = 0; i < blockCount; i++) {
        final r = pyramidRes[i].clamp(1, 24);
        final spm = pyramidSpm[i];
        steps.add(
          WorkoutStep(
            id: 'step_${nowMs}_pyr_$i',
            title: i == 2
                ? 'Sommet Pyramide (Puissance Max SMR $r)'
                : 'Palier Pyramide ${i + 1}/$blockCount (SMR $r)',
            type: StepType.work,
            durationSeconds: blockSec,
            targetResistance: r,
            targetSpmMin: spm - 1,
            targetSpmMax: spm + 2,
            targetWatts: (baseWatts * (0.95 + (i == 2 ? 0.35 : 0.15))).round(),
            notes: isStrengthFocus
                ? 'Poussée puissante des jambes à rythme lent et contrôlé.'
                : (i == 2
                    ? 'Poussée dynamique des jambes sur le sommet de pyramide !'
                    : 'Maintenez une cadence régulière.'),
          ),
        );
      }
    } else if (isTabataOrShortHiit) {
      const workSec = 45;
      const restSec = 45;
      final intervals = (coreSeconds ~/ (workSec + restSec)).clamp(3, 25);
      final hiitSpmMin = switch (user.level) {
        FitnessLevel.beginner => 24,
        FitnessLevel.intermediate => 26,
        FitnessLevel.advanced => 28,
      };
      final hiitSpmMax = switch (user.level) {
        FitnessLevel.beginner => 28,
        FitnessLevel.intermediate => 30,
        FitnessLevel.advanced => 32,
      };

      for (int i = 1; i <= intervals; i++) {
        final currentRes =
            (i % 2 == 0 ? peakRes : workRes).clamp(restRes + 2, 24);
        steps.add(
          WorkoutStep(
            id: 'step_${nowMs}_hiit_w_$i',
            title: 'Sprint Fractionné #$i/$intervals (SMR $currentRes)',
            type: StepType.work,
            durationSeconds: workSec,
            targetResistance: currentRes,
            targetSpmMin: hiitSpmMin,
            targetSpmMax: hiitSpmMax,
            targetWatts: (baseWatts * 1.35).round(),
            notes: 'Attaque franche des jambes tout en gardant le dos gainé.',
          ),
        );
        steps.add(
          WorkoutStep(
            id: 'step_${nowMs}_hiit_r_$i',
            title: 'Récupération Active #$i/$intervals',
            type: StepType.rest,
            durationSeconds: restSec,
            targetResistance: restRes,
            targetSpmMin: 18,
            targetSpmMax: 21,
            targetWatts: (baseWatts * 0.55).round(),
            notes: 'Soufflez profondément sur le retour de coulisse.',
          ),
        );
      }
    } else if (isEndurance) {
      final blocks = 3;
      final workSec = ((coreSeconds ~/ blocks) - 60).clamp(120, 900);
      for (int i = 1; i <= blocks; i++) {
        final r = (workRes + (i - 1)).clamp(restRes + 1, 20);
        steps.add(
          WorkoutStep(
            id: 'step_${nowMs}_end_w_$i',
            title: 'Bloc Tempo Aérobie $i/$blocks (SMR $r)',
            type: StepType.work,
            durationSeconds: workSec,
            targetResistance: r,
            targetSpmMin: user.level == FitnessLevel.beginner ? 19 : 22,
            targetSpmMax: user.level == FitnessLevel.beginner ? 22 : 25,
            targetWatts: baseWatts,
            notes: 'Ratio 1 temps tirage / 2 temps retour coulisse.',
          ),
        );
        if (i < blocks) {
          steps.add(
            WorkoutStep(
              id: 'step_${nowMs}_end_r_$i',
              title: 'Transition souple',
              type: StepType.rest,
              durationSeconds: 60,
              targetResistance: restRes,
              targetSpmMin: 18,
              targetSpmMax: 20,
              targetWatts: (baseWatts * 0.6).round(),
              notes: 'Relâchez les épaules et hydratez-vous.',
            ),
          );
        }
      }
    } else {
      const workSec = 90;
      const restSec = 45;
      final cycles = (coreSeconds ~/ (workSec + restSec)).clamp(3, 18);
      final intSpmMin = switch (user.level) {
        FitnessLevel.beginner => 22,
        FitnessLevel.intermediate => 24,
        FitnessLevel.advanced => 26,
      };
      final intSpmMax = intSpmMin + 4;
      for (int i = 1; i <= cycles; i++) {
        final r = (i == cycles ? peakRes : workRes).clamp(restRes + 2, 24);
        steps.add(
          WorkoutStep(
            id: 'step_${nowMs}_int_w_$i',
            title: i == cycles
                ? 'Intervalle Final Boost #$i/$cycles (SMR $r)'
                : 'Intervalle Intensif #$i/$cycles (SMR $r)',
            type: StepType.work,
            durationSeconds: workSec,
            targetResistance: r,
            targetSpmMin: intSpmMin,
            targetSpmMax: intSpmMax,
            targetWatts: (baseWatts * 1.2).round(),
            notes:
                'Maintenez la puissance au-dessus de ${(baseWatts * 1.15).round()} W.',
          ),
        );
        steps.add(
          WorkoutStep(
            id: 'step_${nowMs}_int_r_$i',
            title: 'Récupération Active #$i/$cycles',
            type: StepType.rest,
            durationSeconds: restSec,
            targetResistance: restRes,
            targetSpmMin: 18,
            targetSpmMax: 22,
            targetWatts: (baseWatts * 0.6).round(),
            notes: 'Baisse automatique de la résistance SMR à $restRes.',
          ),
        );
      }
    }

    steps.add(
      WorkoutStep(
        id: 'step_${nowMs}_cooldown',
        title: 'Retour au calme & relâchement',
        type: StepType.cooldown,
        durationSeconds: cooldownSec,
        targetResistance: max(1, restRes - 1),
        targetSpmMin: 16,
        targetSpmMax: 20,
        targetWatts: (baseWatts * 0.5).round(),
        notes: 'Ramez sans forcer pour faire redescendre le rythme cardiaque.',
      ),
    );

    final generatedTitle = customTitle ??
        (focusPrompt.trim().isNotEmpty
            ? 'IA • ${focusPrompt.trim()}'
            : 'Coach IA • ${user.goal.label} ($durationMinutes min)');

    final rawWorkout = Workout(
      id: 'ai_$nowMs',
      title: generatedTitle,
      description:
          'Séance générée par IA pour ${user.name} (${user.age} ans, ${user.heightCm} cm, ${user.weightKg.toInt()} kg • Objectif ${user.goal.label}) • Pilotage SMR de $restRes à $peakRes.',
      category: 'ai',
      createdByUserId: user.id,
      isAiGenerated: true,
      steps: steps,
      createdAt: DateTime.now(),
    );

    return _validateAndSanitizeWorkout(rawWorkout);
  }

  /// Valide et garantit la cohérence biomécanique stricte d'une séance :
  /// 1. Forte résistance => cadence modérée/lente (protège le dos et les genoux).
  /// 2. Le repos ou retour au calme ne peut JAMAIS avoir une résistance, puissance ou cadence supérieure au travail.
  static Workout _validateAndSanitizeWorkout(Workout workout) {
    if (workout.steps.isEmpty) return workout;

    // 1. Protéger les phases d'effort contre le cumul haute résistance + haute cadence
    final safeWorkSteps = workout.steps.map((step) {
      if (step.type != StepType.work) return step;
      if (step.targetResistance >= 15 && step.targetSpmMax > 22) {
        final spmMax = 22;
        final spmMin = min(step.targetSpmMin, 19);
        return step.copyWith(targetSpmMin: spmMin, targetSpmMax: spmMax);
      }
      if (step.targetResistance >= 12 && step.targetSpmMax > 26) {
        final spmMax = 26;
        final spmMin = min(step.targetSpmMin, 23);
        return step.copyWith(targetSpmMin: spmMin, targetSpmMax: spmMax);
      }
      return step;
    }).toList();

    final workSteps =
        safeWorkSteps.where((s) => s.type == StepType.work).toList();
    final minWorkRes = workSteps.isEmpty
        ? 6
        : workSteps.map((s) => s.targetResistance).reduce(min);
    final minWorkWatts = workSteps.isEmpty
        ? 120
        : (workSteps.where((s) => s.targetWatts != null).isEmpty
            ? 120
            : workSteps
                .where((s) => s.targetWatts != null)
                .map((s) => s.targetWatts!)
                .reduce(min));
    final minWorkSpm = workSteps.isEmpty
        ? 24
        : workSteps.map((s) => s.targetSpmMin).reduce(min);

    final sanitizedSteps = <WorkoutStep>[];
    for (final step in safeWorkSteps) {
      if (step.type == StepType.rest || step.type == StepType.cooldown) {
        // Le repos ou cooldown DOIT STRICTEMENT être inférieur au travail
        final maxAllowedRes = max(
          1,
          minWorkRes - (step.type == StepType.cooldown ? 2 : 1),
        );
        final sanitizedRes = step.targetResistance.clamp(1, maxAllowedRes);

        final sanitizedWatts = step.targetWatts != null
            ? min(step.targetWatts!, (minWorkWatts * 0.65).round())
            : null;

        final sanitizedSpmMax = min(step.targetSpmMax, max(18, minWorkSpm - 2));
        final sanitizedSpmMin = min(step.targetSpmMin, sanitizedSpmMax - 2);

        sanitizedSteps.add(
          step.copyWith(
            targetResistance: sanitizedRes,
            targetWatts: sanitizedWatts,
            targetSpmMin: sanitizedSpmMin,
            targetSpmMax: sanitizedSpmMax,
          ),
        );
      } else {
        sanitizedSteps.add(step);
      }
    }

    return workout.copyWith(steps: sanitizedSteps);
  }
}

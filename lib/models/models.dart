import 'dart:convert';

enum FitnessLevel {
  beginner('Débutant', 'Reprise & découverte'),
  intermediate('Intermédiaire', 'Pratique régulière'),
  advanced('Avancé', 'Haute intensité');

  final String label;
  final String subtitle;
  const FitnessLevel(this.label, this.subtitle);

  static FitnessLevel fromName(String? name) {
    return FitnessLevel.values.firstWhere(
      (e) => e.name == name,
      orElse: () => FitnessLevel.intermediate,
    );
  }
}

enum WorkoutGoal {
  endurance(
    'Cardio & Endurance',
    'Souffle et régularité',
    'Ramer à un rythme confortable et régulier pour améliorer votre souffle, votre cœur et tenir plus longtemps sans vous épuiser.',
    '20 - 24 coups/min',
    'Niveau 6 à 12 / 24',
    'Meilleur souffle et endurance au quotidien',
    'Gardez une allure où vous pouvez encore parler : priorité au geste fluide.',
  ),
  hiitWeightLoss(
    'Brûle-Graisses (HIIT)',
    'Alternance rapide & récup',
    'Alterner des phases dynamiques plus rapides avec des pauses actives pour dépenser un maximum d\'énergie en moins de temps.',
    '26 - 30 coups/min',
    'Niveau 8 à 14 / 24',
    'Dépense d\'énergie élevée en séance courte',
    'Gardez une résistance modérée : pour aller vite en sécurité, on ne charge pas trop lourd.',
  ),
  powerStrength(
    'Force & Tonus',
    'Poussée puissante à rythme lent',
    'Ramer lentement contre une résistance plus élevée pour renforcer les jambes, le dos et la sangle abdominale sans précipitation.',
    '16 - 22 coups/min',
    'Niveau 12 à 18 / 24',
    'Jambes, dos et posture plus solides',
    'Poussez fort avec les jambes à rythme lent et contrôlé, le dos bien droit.',
  ),
  recovery(
    'Récupération & Technique',
    'Séance douce et fluide',
    'Ramer très tranquillement pour détendre les muscles, améliorer la souplesse et perfectionner votre mouvement sans fatigue.',
    '16 - 20 coups/min',
    'Niveau 1 à 5 / 24',
    'Détente musculaire et maîtrise du geste',
    'Décomposez le geste sans forcer : Jambes → Dos → Bras, puis Bras → Dos → Jambes.',
  );

  final String label;
  final String subtitle;
  final String description;
  final String targetCadence;
  final String targetResistance;
  final String keyBenefit;
  final String beginnerTip;

  const WorkoutGoal(
    this.label,
    this.subtitle,
    this.description,
    this.targetCadence,
    this.targetResistance,
    this.keyBenefit,
    this.beginnerTip,
  );

  /// Cadence recommandée (en coups de rame / min, aussi appelés SPM) adaptée au niveau.
  String cadenceForLevel(FitnessLevel level) {
    return switch (this) {
      WorkoutGoal.endurance => switch (level) {
          FitnessLevel.beginner => '18 - 22 coups/min',
          FitnessLevel.intermediate => '20 - 24 coups/min',
          FitnessLevel.advanced => '22 - 26 coups/min',
        },
      WorkoutGoal.hiitWeightLoss => switch (level) {
          FitnessLevel.beginner => '24 - 28 coups/min',
          FitnessLevel.intermediate => '26 - 30 coups/min',
          FitnessLevel.advanced => '28 - 34 coups/min',
        },
      WorkoutGoal.powerStrength => switch (level) {
          FitnessLevel.beginner => '16 - 20 coups/min',
          FitnessLevel.intermediate => '18 - 22 coups/min',
          FitnessLevel.advanced => '18 - 22 coups/min',
        },
      WorkoutGoal.recovery => switch (level) {
          FitnessLevel.beginner => '16 - 20 coups/min',
          FitnessLevel.intermediate => '18 - 20 coups/min',
          FitnessLevel.advanced => '18 - 22 coups/min',
        },
    };
  }

  /// Plage de résistance SMR (1..24) adaptée au niveau pour rester sain et progressif.
  String resistanceForLevel(FitnessLevel level) {
    return switch (this) {
      WorkoutGoal.endurance => switch (level) {
          FitnessLevel.beginner => 'Niveau 4 à 8 (Modérée)',
          FitnessLevel.intermediate => 'Niveau 6 à 12 (Modérée)',
          FitnessLevel.advanced => 'Niveau 10 à 15 (Soutenue)',
        },
      WorkoutGoal.hiitWeightLoss => switch (level) {
          FitnessLevel.beginner => 'Niveau 5 à 10 (Modérée)',
          FitnessLevel.intermediate => 'Niveau 8 à 14 (Soutenue)',
          FitnessLevel.advanced => 'Niveau 10 à 18 (Intense)',
        },
      WorkoutGoal.powerStrength => switch (level) {
          FitnessLevel.beginner => 'Niveau 9 à 13 (Ferme)',
          FitnessLevel.intermediate => 'Niveau 12 à 18 (Forte)',
          FitnessLevel.advanced => 'Niveau 16 à 24 (Maximale)',
        },
      WorkoutGoal.recovery => switch (level) {
          FitnessLevel.beginner => 'Niveau 1 à 4 (Très douce)',
          FitnessLevel.intermediate => 'Niveau 1 à 5 (Douce)',
          FitnessLevel.advanced => 'Niveau 2 à 6 (Douce)',
        },
    };
  }

  static WorkoutGoal fromName(String? name) {
    return WorkoutGoal.values.firstWhere(
      (e) => e.name == name,
      orElse: () => WorkoutGoal.hiitWeightLoss,
    );
  }
}

class UserProfile {
  final String id;
  final String name; // Pseudo
  final String avatarEmoji;
  final int colorValue;
  final double weightKg; // Poids
  final int heightCm; // Taille (cm)
  final int age; // Âge
  final int maxHeartRate;
  final FitnessLevel level;
  final WorkoutGoal goal; // Objectif
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.name,
    this.avatarEmoji = '🚣',
    this.colorValue = 0xFF0284C7,
    required this.weightKg,
    this.heightCm = 178,
    required this.age,
    int? maxHeartRate,
    this.level = FitnessLevel.intermediate,
    required this.goal,
    required this.createdAt,
  }) : maxHeartRate = maxHeartRate ?? (220 - age);

  /// Formule officielle Pro-Form / iFit utilisée dans proformrower.cpp :
  /// KCal/min = ((0.048 * watts + 1.19) * weightKg * 3.5) / 200.0
  double computeCaloriesForDuration({
    required double avgWatts,
    required int durationSeconds,
  }) {
    if (durationSeconds <= 0 || avgWatts <= 0) return 0.0;
    final kcalPerMinute =
        ((0.048 * avgWatts + 1.19) * weightKg * 3.5) / 200.0;
    return kcalPerMinute * (durationSeconds / 60.0);
  }

  UserProfile copyWith({
    String? name,
    String? avatarEmoji,
    int? colorValue,
    double? weightKg,
    int? heightCm,
    int? age,
    int? maxHeartRate,
    FitnessLevel? level,
    WorkoutGoal? goal,
  }) {
    final updatedAge = age ?? this.age;
    return UserProfile(
      id: id,
      name: name ?? this.name,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      colorValue: colorValue ?? this.colorValue,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      age: updatedAge,
      maxHeartRate: maxHeartRate ?? (220 - updatedAge).clamp(140, 210),
      level: level ?? this.level,
      goal: goal ?? this.goal,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarEmoji': avatarEmoji,
        'colorValue': colorValue,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'age': age,
        'maxHeartRate': maxHeartRate,
        'level': level.name,
        'goal': goal.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String? ?? 'user_primary',
        name: json['name'] as String? ?? 'Matthieu',
        avatarEmoji: json['avatarEmoji'] as String? ?? '🚣',
        colorValue: json['colorValue'] as int? ?? 0xFF0284C7,
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 75.0,
        heightCm: (json['heightCm'] as num?)?.toInt() ?? 178,
        age: json['age'] as int? ?? 35,
        maxHeartRate: json['maxHeartRate'] as int? ?? 185,
        level: FitnessLevel.fromName(json['level'] as String?),
        goal: WorkoutGoal.fromName(json['goal'] as String?),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

enum WorkoutTemplateType {
  endurance(
    'Endurance fondamentale',
    'Allure modérée et régulière (18–22 SPM)',
    'Développe le cœur et l’endurance de base sans fatigue excessive. Idéal pour brûler les graisses et construire son fond de caisse.',
  ),
  tempo(
    'Tempo / Seuil',
    'Blocs longs à allure soutenue (22–26 SPM)',
    'Habitue le corps à maintenir un rythme élevé plus longtemps en repoussant le seuil de fatigue musculaire.',
  ),
  longIntervals(
    'Fractionné long',
    'Intervalles de 2 à 5 min avec récup (26–30 SPM)',
    'Améliore la VO2max et la puissance aérobie. Très efficace pour progresser rapidement sur des distances moyennes.',
  ),
  hiit(
    'Fractionné court / HIIT',
    'Sprints explosifs 30/30 ou Tabata (28–34 SPM)',
    'Booste le métabolisme, l’explosivité et la dépense calorique en un minimum de temps.',
  ),
  pyramid(
    'Pyramide',
    'Montée puis descente de résistance et durée',
    'Casse la monotonie tout en sollicitant progressivement l’endurance, la force puis le retour au calme.',
  ),
  strength(
    'Force / Puissance',
    'Basse cadence (16–20 SPM), forte résistance SMR',
    'Renforce les jambes, le dos et le gainage grâce à des coups de rame lents et puissants contre une résistance élevée.',
  ),
  timeTrial(
    'Contre-la-montre',
    'Effort continu maximal de référence',
    'Sert de test étalon pour mesurer votre niveau actuel et suivre vos progrès d’un mois sur l’autre.',
  ),
  recovery(
    'Récupération / Technique',
    'Séance douce (16–20 SPM) et relâchement',
    'Favorise la récupération active entre deux grosses séances et permet de perfectionner le geste (jambes → dos → bras).',
  );

  final String label;
  final String subtitle;
  final String benefit;
  const WorkoutTemplateType(this.label, this.subtitle, this.benefit);
}

enum StepType {
  warmup('Échauffement'),
  work('Effort'),
  rest('Récupération'),
  cooldown('Retour au calme');

  final String label;
  const StepType(this.label);

  static StepType fromName(String? name) {
    return StepType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => StepType.work,
    );
  }
}

class WorkoutStep {
  final String id;
  final String title;
  final StepType type;
  final int durationSeconds;
  final int? targetDistanceMeters;
  final int targetResistance; // 1..24 SMR sur Pro-Form Sport RL
  final int targetSpmMin;
  final int targetSpmMax;
  final int? targetWatts;
  final String notes;

  const WorkoutStep({
    required this.id,
    required this.title,
    required this.type,
    required this.durationSeconds,
    this.targetDistanceMeters,
    required this.targetResistance,
    required this.targetSpmMin,
    required this.targetSpmMax,
    this.targetWatts,
    this.notes = '',
  });

  WorkoutStep copyWith({
    String? id,
    String? title,
    StepType? type,
    int? durationSeconds,
    int? targetDistanceMeters,
    int? targetResistance,
    int? targetSpmMin,
    int? targetSpmMax,
    int? targetWatts,
    String? notes,
  }) {
    return WorkoutStep(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      targetDistanceMeters: targetDistanceMeters ?? this.targetDistanceMeters,
      targetResistance: (targetResistance ?? this.targetResistance).clamp(1, 24),
      targetSpmMin: targetSpmMin ?? this.targetSpmMin,
      targetSpmMax: targetSpmMax ?? this.targetSpmMax,
      targetWatts: targetWatts ?? this.targetWatts,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'durationSeconds': durationSeconds,
        'targetDistanceMeters': targetDistanceMeters,
        'targetResistance': targetResistance,
        'targetSpmMin': targetSpmMin,
        'targetSpmMax': targetSpmMax,
        'targetWatts': targetWatts,
        'notes': notes,
      };

  factory WorkoutStep.fromJson(Map<String, dynamic> json) => WorkoutStep(
        id: json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title'] as String? ?? 'Intervalle',
        type: StepType.fromName(json['type'] as String?),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 60,
        targetDistanceMeters: (json['targetDistanceMeters'] as num?)?.toInt(),
        targetResistance:
            ((json['targetResistance'] as num?)?.toInt() ?? 8).clamp(1, 24),
        targetSpmMin: (json['targetSpmMin'] as num?)?.toInt() ?? 22,
        targetSpmMax: (json['targetSpmMax'] as num?)?.toInt() ?? 26,
        targetWatts: (json['targetWatts'] as num?)?.toInt(),
        notes: json['notes'] as String? ?? '',
      );
}

class Workout {
  final String id;
  final String title;
  final String description;
  final String category; // 'hiit', 'endurance', 'pyramid', 'custom', 'ai'
  final String? createdByUserId;
  final bool isAiGenerated;
  final List<WorkoutStep> steps;
  final DateTime createdAt;

  const Workout({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.createdByUserId,
    this.isAiGenerated = false,
    required this.steps,
    required this.createdAt,
  });

  Workout copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? createdByUserId,
    bool? isAiGenerated,
    List<WorkoutStep>? steps,
    DateTime? createdAt,
  }) {
    return Workout(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  int get totalDurationSeconds =>
      steps.fold(0, (sum, step) => sum + step.durationSeconds);

  int get maxResistance => steps.isEmpty
      ? 1
      : steps.map((s) => s.targetResistance).reduce((a, b) => a > b ? a : b);

  double get avgResistance {
    if (steps.isEmpty || totalDurationSeconds == 0) return 1.0;
    final weighted = steps.fold<double>(
      0.0,
      (sum, s) => sum + s.targetResistance * s.durationSeconds,
    );
    return weighted / totalDurationSeconds;
  }

  String get formattedDuration {
    final minutes = totalDurationSeconds ~/ 60;
    final seconds = totalDurationSeconds % 60;
    if (seconds == 0) return '$minutes min';
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'createdByUserId': createdByUserId,
        'isAiGenerated': isAiGenerated,
        'steps': steps.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
        id: json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title'] as String? ?? 'Entraînement',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'custom',
        createdByUserId: json['createdByUserId'] as String?,
        isAiGenerated: json['isAiGenerated'] as bool? ?? false,
        steps: (json['steps'] as List<dynamic>? ?? [])
            .map((e) => WorkoutStep.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class ScheduledProgramSession {
  final String id;
  final int index;
  final int weekNumber;
  final int sessionInWeek;
  final int weekday; // 1 = Lundi .. 7 = Dimanche
  final String trainingTime; // ex: '18:30'
  final DateTime scheduledDateTime;
  final Workout workout;
  final bool isCompleted;

  const ScheduledProgramSession({
    required this.id,
    required this.index,
    required this.weekNumber,
    required this.sessionInWeek,
    required this.weekday,
    required this.trainingTime,
    required this.scheduledDateTime,
    required this.workout,
    required this.isCompleted,
  });

  String get weekdayLabel => TrainingProgram.weekdayFullName(weekday);
  String get weekdayShortLabel => TrainingProgram.weekdayShortName(weekday);
}

class TrainingProgram {
  final String id;
  final String title;
  final String description;
  final String userId;
  final WorkoutGoal goal;
  final int weeksCount;
  final int sessionsPerWeek;
  final List<int> trainingDays; // 1 = Lundi .. 7 = Dimanche
  final String trainingTime; // HH:mm
  final bool notificationsEnabled;
  final bool isAiGenerated;
  final List<Workout> workouts;
  final List<String> completedWorkoutIds;
  final DateTime createdAt;

  const TrainingProgram({
    required this.id,
    required this.title,
    required this.description,
    required this.userId,
    this.goal = WorkoutGoal.hiitWeightLoss,
    required this.weeksCount,
    required this.sessionsPerWeek,
    this.trainingDays = const [1, 3, 5],
    this.trainingTime = '18:30',
    this.notificationsEnabled = true,
    this.isAiGenerated = true,
    required this.workouts,
    this.completedWorkoutIds = const [],
    required this.createdAt,
  });

  double get progressRatio => workouts.isEmpty
      ? 0.0
      : (completedWorkoutIds.length / workouts.length).clamp(0.0, 1.0);

  int get progressPercent => (progressRatio * 100).round();

  static String weekdayShortName(int weekday) {
    return switch (weekday) {
      1 => 'Lun',
      2 => 'Mar',
      3 => 'Mer',
      4 => 'Jeu',
      5 => 'Ven',
      6 => 'Sam',
      7 => 'Dim',
      _ => 'Lun',
    };
  }

  static String weekdayFullName(int weekday) {
    return switch (weekday) {
      1 => 'Lundi',
      2 => 'Mardi',
      3 => 'Mercredi',
      4 => 'Jeudi',
      5 => 'Vendredi',
      6 => 'Samedi',
      7 => 'Dimanche',
      _ => 'Lundi',
    };
  }

  String get formattedDaysSummary {
    final sorted = List<int>.from(trainingDays)..sort();
    return sorted.map(weekdayShortName).join(', ');
  }

  List<ScheduledProgramSession> buildSchedule() {
    final days = trainingDays.isNotEmpty
        ? (List<int>.from(trainingDays)..sort())
        : [1, 3, 5];
    final timeParts = trainingTime.split(':');
    final hour = timeParts.isNotEmpty ? (int.tryParse(timeParts[0]) ?? 18) : 18;
    final minute =
        timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 30) : 30;

    // Calcul de la toute première séance : JAMAIS dans le passé !
    // Si aujourd'hui est un jour d'entraînement et l'heure n'est pas passée, on démarre aujourd'hui,
    // sinon on cherche le tout premier jour d'entraînement à venir.
    final now = createdAt;
    DateTime firstSessionDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    int daysOffset = 0;
    while (daysOffset < 7) {
      final candidate = DateTime(
        now.year,
        now.month,
        now.day + daysOffset,
        hour,
        minute,
      );
      if (days.contains(candidate.weekday)) {
        if (daysOffset > 0 || !now.isAfter(candidate)) {
          firstSessionDate = candidate;
          break;
        }
      }
      daysOffset++;
    }

    final startDayIdx = days.indexOf(firstSessionDate.weekday);
    int currentDayIdx = startDayIdx >= 0 ? startDayIdx : 0;
    DateTime currentCursor = firstSessionDate;

    final result = <ScheduledProgramSession>[];
    for (int i = 0; i < workouts.length; i++) {
      final wk = workouts[i];
      final sessionUniqueKey = '${id}_s$i';
      final isDone = completedWorkoutIds.contains(wk.id) ||
          completedWorkoutIds.contains(sessionUniqueKey);

      result.add(
        ScheduledProgramSession(
          id: sessionUniqueKey,
          index: i,
          weekNumber: (i ~/ sessionsPerWeek) + 1,
          sessionInWeek: (i % sessionsPerWeek) + 1,
          weekday: currentCursor.weekday,
          trainingTime: trainingTime,
          scheduledDateTime: currentCursor,
          workout: wk,
          isCompleted: isDone,
        ),
      );

      // Calcul de la date de la séance suivante en avançant vers le prochain jour prévu
      currentDayIdx = (currentDayIdx + 1) % days.length;
      final nextWeekday = days[currentDayIdx];
      int addDays = (nextWeekday - currentCursor.weekday + 7) % 7;
      if (addDays == 0) addDays = 7;
      currentCursor = currentCursor.add(Duration(days: addDays));
    }
    return result;
  }

  ScheduledProgramSession? get nextScheduledSession {
    final sched = buildSchedule();
    for (final s in sched) {
      if (!s.isCompleted) return s;
    }
    return sched.isNotEmpty ? sched.last : null;
  }

  TrainingProgram copyWith({
    String? title,
    String? description,
    WorkoutGoal? goal,
    int? weeksCount,
    int? sessionsPerWeek,
    List<int>? trainingDays,
    String? trainingTime,
    bool? notificationsEnabled,
    bool? isAiGenerated,
    List<Workout>? workouts,
    List<String>? completedWorkoutIds,
  }) {
    return TrainingProgram(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      userId: userId,
      goal: goal ?? this.goal,
      weeksCount: weeksCount ?? this.weeksCount,
      sessionsPerWeek: sessionsPerWeek ?? this.sessionsPerWeek,
      trainingDays: trainingDays ?? this.trainingDays,
      trainingTime: trainingTime ?? this.trainingTime,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      workouts: workouts ?? this.workouts,
      completedWorkoutIds: completedWorkoutIds ?? this.completedWorkoutIds,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'userId': userId,
        'goal': goal.name,
        'weeksCount': weeksCount,
        'sessionsPerWeek': sessionsPerWeek,
        'trainingDays': trainingDays,
        'trainingTime': trainingTime,
        'notificationsEnabled': notificationsEnabled,
        'isAiGenerated': isAiGenerated,
        'workouts': workouts.map((w) => w.toJson()).toList(),
        'completedWorkoutIds': completedWorkoutIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TrainingProgram.fromJson(Map<String, dynamic> json) =>
      TrainingProgram(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        userId: json['userId'] as String? ?? 'user_primary',
        goal: WorkoutGoal.fromName(json['goal'] as String?),
        weeksCount: json['weeksCount'] as int? ?? 4,
        sessionsPerWeek: json['sessionsPerWeek'] as int? ?? 3,
        trainingDays: (json['trainingDays'] as List<dynamic>?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const [1, 3, 5],
        trainingTime: json['trainingTime'] as String? ?? '18:30',
        notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
        isAiGenerated: json['isAiGenerated'] as bool? ?? true,
        workouts: (json['workouts'] as List<dynamic>? ?? [])
            .map((e) => Workout.fromJson(e as Map<String, dynamic>))
            .toList(),
        completedWorkoutIds:
            (json['completedWorkoutIds'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

enum SessionSource {
  liveBle('BLE Sport RL'),
  lateSyncConsole('Synchro Console'),
  ifitImport('Import CSV');

  final String label;
  const SessionSource(this.label);

  static SessionSource fromName(String? name) {
    return SessionSource.values.firstWhere(
      (e) => e.name == name,
      orElse: () => SessionSource.liveBle,
    );
  }
}

class SessionSample {
  final int elapsedSeconds;
  final int watts;
  final int cadenceSpm;
  final int resistance;
  final double distanceMeters;
  final double speedKmh;
  final int heartRateBpm;

  const SessionSample({
    required this.elapsedSeconds,
    required this.watts,
    required this.cadenceSpm,
    required this.resistance,
    required this.distanceMeters,
    required this.speedKmh,
    this.heartRateBpm = 0,
  });

  Map<String, dynamic> toJson() => {
        't': elapsedSeconds,
        'w': watts,
        'spm': cadenceSpm,
        'r': resistance,
        'd': distanceMeters,
        'v': speedKmh,
        'hr': heartRateBpm,
      };

  factory SessionSample.fromJson(Map<String, dynamic> json) => SessionSample(
        elapsedSeconds: (json['t'] as num?)?.toInt() ?? 0,
        watts: (json['w'] as num?)?.toInt() ?? 0,
        cadenceSpm: (json['spm'] as num?)?.toInt() ?? 0,
        resistance: (json['r'] as num?)?.toInt() ?? 1,
        distanceMeters: (json['d'] as num?)?.toDouble() ?? 0.0,
        speedKmh: (json['v'] as num?)?.toDouble() ?? 0.0,
        heartRateBpm: (json['hr'] as num?)?.toInt() ?? 0,
      );
}

class RowingSession {
  final String id;
  final String? userId;
  final String? workoutId;
  final String workoutTitle;
  final DateTime startedAt;
  final int durationSeconds;
  final double distanceMeters;
  final double avgWatts;
  final int maxWatts;
  final double avgCadenceSpm;
  final double avgResistance;
  final double caloriesKcal;
  final int strokesCount;
  final SessionSource source;
  final List<SessionSample> samples;
  final String notes;

  const RowingSession({
    required this.id,
    this.userId,
    this.workoutId,
    required this.workoutTitle,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.avgWatts,
    required this.maxWatts,
    required this.avgCadenceSpm,
    required this.avgResistance,
    required this.caloriesKcal,
    required this.strokesCount,
    required this.source,
    this.samples = const [],
    this.notes = '',
  });

  bool get isAssigned => userId != null && userId!.isNotEmpty;

  /// Allure moyenne en secondes par 500m (Split /500m)
  double get avgSplitSecondsPer500m {
    if (distanceMeters <= 10 || durationSeconds <= 0) return 0.0;
    return (durationSeconds / distanceMeters) * 500.0;
  }

  String get formattedSplit {
    final split = avgSplitSecondsPer500m;
    if (split <= 0 || split > 600) return '--:--';
    final min = split ~/ 60;
    final sec = (split % 60).round().clamp(0, 59);
    return '$min:${sec.toString().padLeft(2, '0')} /500m';
  }

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Associe ou réattribue la session à un profil utilisateur et recalcule les KCal
  RowingSession assignToUser(UserProfile user) {
    final updatedKcal = user.computeCaloriesForDuration(
      avgWatts: avgWatts,
      durationSeconds: durationSeconds,
    );
    return RowingSession(
      id: id,
      userId: user.id,
      workoutId: workoutId,
      workoutTitle: workoutTitle,
      startedAt: startedAt,
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
      avgWatts: avgWatts,
      maxWatts: maxWatts,
      avgCadenceSpm: avgCadenceSpm,
      avgResistance: avgResistance,
      caloriesKcal: updatedKcal > 0 ? updatedKcal : caloriesKcal,
      strokesCount: strokesCount,
      source: source,
      samples: samples,
      notes: notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'workoutId': workoutId,
        'workoutTitle': workoutTitle,
        'startedAt': startedAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'distanceMeters': distanceMeters,
        'avgWatts': avgWatts,
        'maxWatts': maxWatts,
        'avgCadenceSpm': avgCadenceSpm,
        'avgResistance': avgResistance,
        'caloriesKcal': caloriesKcal,
        'strokesCount': strokesCount,
        'source': source.name,
        'samples': samples.map((s) => s.toJson()).toList(),
        'notes': notes,
      };

  factory RowingSession.fromJson(Map<String, dynamic> json) => RowingSession(
        id: json['id'] as String,
        userId: json['userId'] as String?,
        workoutId: json['workoutId'] as String?,
        workoutTitle: json['workoutTitle'] as String? ?? 'Session Libre',
        startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
            DateTime.now(),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
        avgWatts: (json['avgWatts'] as num?)?.toDouble() ?? 0.0,
        maxWatts: (json['maxWatts'] as num?)?.toInt() ?? 0,
        avgCadenceSpm: (json['avgCadenceSpm'] as num?)?.toDouble() ?? 0.0,
        avgResistance: (json['avgResistance'] as num?)?.toDouble() ?? 1.0,
        caloriesKcal: (json['caloriesKcal'] as num?)?.toDouble() ?? 0.0,
        strokesCount: (json['strokesCount'] as num?)?.toInt() ?? 0,
        source: SessionSource.fromName(json['source'] as String?),
        samples: (json['samples'] as List<dynamic>? ?? [])
            .map((e) => SessionSample.fromJson(e as Map<String, dynamic>))
            .toList(),
        notes: json['notes'] as String? ?? '',
      );

  static String encodeList(List<RowingSession> sessions) =>
      jsonEncode(sessions.map((s) => s.toJson()).toList());

  static List<RowingSession> decodeList(String raw) =>
      (jsonDecode(raw) as List<dynamic>)
          .map((e) => RowingSession.fromJson(e as Map<String, dynamic>))
          .toList();
}

class RowerTelemetry {
  final bool isConnected;
  final bool isInitializing;
  final int initStepProgress;
  final int initStepTotal;
  final String deviceName;
  final String deviceId;
  final int cadenceSpm;
  final int powerWatts;
  final int resistanceLevel; // 1..24 SMR
  final int? pendingTargetResistance;
  final double distanceMeters;
  final double speedKmh;
  final double caloriesKcal;
  final int strokesCount;
  final int elapsedSeconds;
  final int heartRateBpm;
  final int rxPacketsCount;
  final double? consoleDetectedUnsyncedMeters;
  final bool isConsolePaused;

  const RowerTelemetry({
    this.isConnected = false,
    this.isInitializing = false,
    this.initStepProgress = 0,
    this.initStepTotal = 0,
    this.deviceName = 'Non connecté',
    this.deviceId = '',
    this.cadenceSpm = 0,
    this.powerWatts = 0,
    this.resistanceLevel = 1,
    this.pendingTargetResistance,
    this.distanceMeters = 0.0,
    this.speedKmh = 0.0,
    this.caloriesKcal = 0.0,
    this.strokesCount = 0,
    this.elapsedSeconds = 0,
    this.heartRateBpm = 0,
    this.rxPacketsCount = 0,
    this.consoleDetectedUnsyncedMeters,
    this.isConsolePaused = false,
  });

  int get watts => powerWatts;
  bool get isConnecting => isInitializing;
  String get formattedSplit500m => formattedSplit;

  String get formattedElapsed {
    final m = elapsedSeconds ~/ 60;
    final s = elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Allure instantanée /500m en secondes
  double get splitSecondsPer500m {
    if (speedKmh > 0.5) {
      final metersPerSecond = speedKmh / 3.6;
      return 500.0 / metersPerSecond;
    }
    if (powerWatts > 5) {
      return 500.0 * _cbrt(2.80 / powerWatts);
    }
    return 0.0;
  }

  static double _cbrt(double x) {
    if (x <= 0) return 0.0;
    double guess = 1.0;
    for (int i = 0; i < 12; i++) {
      guess = (2.0 * guess + x / (guess * guess)) / 3.0;
    }
    return guess;
  }

  String get formattedSplit {
    final s = splitSecondsPer500m;
    if (s <= 0 || s > 600) return '--:--';
    final min = s ~/ 60;
    final sec = (s % 60).round().clamp(0, 59);
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  RowerTelemetry copyWith({
    bool? isConnected,
    bool? isInitializing,
    int? initStepProgress,
    int? initStepTotal,
    String? deviceName,
    String? deviceId,
    int? cadenceSpm,
    int? powerWatts,
    int? resistanceLevel,
    int? pendingTargetResistance,
    double? distanceMeters,
    double? speedKmh,
    double? caloriesKcal,
    int? strokesCount,
    int? elapsedSeconds,
    int? heartRateBpm,
    int? rxPacketsCount,
    double? consoleDetectedUnsyncedMeters,
    bool clearConsoleUnsynced = false,
    bool? isConsolePaused,
  }) {
    return RowerTelemetry(
      isConnected: isConnected ?? this.isConnected,
      isInitializing: isInitializing ?? this.isInitializing,
      initStepProgress: initStepProgress ?? this.initStepProgress,
      initStepTotal: initStepTotal ?? this.initStepTotal,
      deviceName: deviceName ?? this.deviceName,
      deviceId: deviceId ?? this.deviceId,
      cadenceSpm: cadenceSpm ?? this.cadenceSpm,
      powerWatts: powerWatts ?? this.powerWatts,
      resistanceLevel: (resistanceLevel ?? this.resistanceLevel).clamp(1, 24),
      pendingTargetResistance: pendingTargetResistance,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      speedKmh: speedKmh ?? this.speedKmh,
      caloriesKcal: caloriesKcal ?? this.caloriesKcal,
      strokesCount: strokesCount ?? this.strokesCount,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      heartRateBpm: heartRateBpm ?? this.heartRateBpm,
      rxPacketsCount: rxPacketsCount ?? this.rxPacketsCount,
      consoleDetectedUnsyncedMeters: clearConsoleUnsynced
          ? null
          : (consoleDetectedUnsyncedMeters ??
              this.consoleDetectedUnsyncedMeters),
      isConsolePaused: isConsolePaused ?? this.isConsolePaused,
    );
  }
}

typedef RowingTelemetry = RowerTelemetry;

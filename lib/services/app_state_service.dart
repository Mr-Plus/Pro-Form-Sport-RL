import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class AppStateService extends ChangeNotifier {
  static const _kUsersKey = 'pf_sport_rl_users_v1';
  static const _kWorkoutsKey = 'pf_sport_rl_workouts_v1';
  static const _kProgramsKey = 'pf_sport_rl_programs_v1';
  static const _kActiveProgramIdKey = 'pf_sport_rl_active_program_id_v1';
  static const _kSessionsKey = 'pf_sport_rl_sessions_v1';
  static const _kGeminiKey = 'pf_sport_rl_gemini_key_v1';
  static const _kThemeModeKey = 'pf_sport_rl_theme_mode_v1';
  static const _kNotificationsKey = 'pf_sport_rl_notifications_v1';

  static const String appVersion = '1.0.0+1';

  // 1 seul profil par application
  UserProfile _user = _defaultSingleUser();
  UserProfile get activeUser => _user;
  List<UserProfile> get users => [_user];

  List<Workout> _workouts = _defaultWorkouts();
  List<Workout> get workouts => List.unmodifiable(_workouts);

  List<TrainingProgram> _programs = [];
  List<TrainingProgram> get programs => List.unmodifiable(_programs);
  String? _activeProgramId;

  TrainingProgram? get activeProgram {
    if (_programs.isEmpty) return null;
    if (_activeProgramId != null) {
      for (final p in _programs) {
        if (p.id == _activeProgramId) return p;
      }
    }
    return _programs.first;
  }

  List<RowingSession> _sessions = [];
  List<RowingSession> get sessions => List.unmodifiable(_sessions);

  static const _legacyFakeSessionIds = {
    'sess_orphan_console_1',
    'sess_orphan_ifit_2',
    'sess_assigned_1',
  };

  List<RowingSession> get unassignedSessions =>
      _sessions.where((s) => !s.isAssigned).toList();

  String _geminiApiKey = '';
  String get geminiApiKey => _geminiApiKey;

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  bool _notificationsEnabled = true;
  bool get notificationsEnabled => _notificationsEnabled;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  /// Détermine si l'utilisateur est rigoureux (à jour dans ses séances) ou en retard
  bool get isUserRigorous {
    final now = DateTime.now();
    final prog = activeProgram;
    if (prog != null) {
      final schedule = prog.buildSchedule();
      final pastDueUncompleted = schedule.where(
        (item) =>
            !item.isCompleted &&
            item.scheduledDateTime.isBefore(
              now.subtract(const Duration(hours: 2)),
            ),
      );
      if (pastDueUncompleted.isNotEmpty) {
        return false;
      }
      if (prog.completedWorkoutIds.isNotEmpty) {
        return true;
      }
    }

    final hasRecentSession = _sessions.any(
      (s) => now.difference(s.startedAt).inHours <= 72,
    );
    if (hasRecentSession && (prog?.completedWorkoutIds.isNotEmpty ?? false)) {
      return true;
    }

    return false;
  }

  /// Phrase du coach personnalisée avec le pseudo (commence toujours par Bonjour/Bonsoir [Pseudo])
  String get coachPhrase {
    final pseudo = _user.name;
    final prog = activeProgram;
    final pct = prog?.progressPercent ?? 0;
    final hour = DateTime.now().hour;
    final greeting = (hour >= 18 || hour < 5) ? 'Bonsoir' : 'Bonjour';

    if (isUserRigorous) {
      return '$greeting $pseudo,\n\nQuelle rigueur exemplaire ($pct% du programme accompli). Continue sur cette lancée de champion, rien ne t\'arrête !';
    } else {
      return '$greeting $pseudo,\n\nOn se relâche ?! Le rameur t\'attend et tu es en retard sur ton programme ! Pas d\'excuse aujourd\'hui, rame !';
    }
  }

  Future<void> init() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('SharedPreferences init fallback: $e');
    }

    // 1. Chargement du profil unique
    final rawUsers = prefs?.getString(_kUsersKey);
    if (rawUsers != null && rawUsers.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawUsers);
        if (decoded is List && decoded.isNotEmpty) {
          _user = UserProfile.fromJson(decoded.first as Map<String, dynamic>);
        } else if (decoded is Map<String, dynamic>) {
          _user = UserProfile.fromJson(decoded);
        }
      } catch (_) {}
    }

    // 2. Chargement des entraînements types
    final rawWorkouts = prefs?.getString(_kWorkoutsKey);
    if (rawWorkouts != null && rawWorkouts.isNotEmpty) {
      try {
        final list = jsonDecode(rawWorkouts) as List<dynamic>;
        _workouts = list
            .map((e) => Workout.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    if (_workouts.isEmpty) {
      _workouts = _defaultWorkouts();
    }

    // 3. Chargement du programme d'entraînement
    final rawPrograms = prefs?.getString(_kProgramsKey);
    if (rawPrograms != null && rawPrograms.isNotEmpty) {
      try {
        final list = jsonDecode(rawPrograms) as List<dynamic>;
        _programs = list
            .map((e) => TrainingProgram.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    if (_programs.isEmpty) {
      _programs = [_defaultProgram(_user, _workouts)];
    }
    _activeProgramId = prefs?.getString(_kActiveProgramIdKey);

    // 4. Chargement des sessions
    final rawSessions = prefs?.getString(_kSessionsKey);
    if (rawSessions != null && rawSessions.isNotEmpty) {
      try {
        final decoded = RowingSession.decodeList(rawSessions);
        final filtered = decoded
            .where((s) => !_legacyFakeSessionIds.contains(s.id))
            .toList();
        _sessions = filtered;
        if (filtered.length != decoded.length) {
          await prefs?.setString(
            _kSessionsKey,
            RowingSession.encodeList(_sessions),
          );
        }
      } catch (_) {}
    }

    // 5. Nettoyage si aucune session n'a été réalisée (progression à 0%)
    if (_sessions.isEmpty && _programs.isNotEmpty) {
      bool changed = false;
      for (int i = 0; i < _programs.length; i++) {
        if (_programs[i].id == 'prog_default_initial' &&
            _programs[i].completedWorkoutIds.isNotEmpty) {
          _programs[i] = _programs[i].copyWith(completedWorkoutIds: const []);
          changed = true;
        }
      }
      if (changed) {
        await prefs?.setString(
          _kProgramsKey,
          jsonEncode(_programs.map((p) => p.toJson()).toList()),
        );
      }
    }

    // 6. Chargement des paramètres (Thème sombre bleu nuit athlétique imposé par défaut)
    _geminiApiKey = prefs?.getString(_kGeminiKey) ?? '';
    _notificationsEnabled = prefs?.getBool(_kNotificationsKey) ?? true;
    _themeMode = ThemeMode.dark;
    await prefs?.setString(_kThemeModeKey, 'dark');

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kUsersKey,
        jsonEncode([_user.toJson()]),
      );
      await prefs.setString(
        _kWorkoutsKey,
        jsonEncode(_workouts.map((w) => w.toJson()).toList()),
      );
      await prefs.setString(
        _kProgramsKey,
        jsonEncode(_programs.map((p) => p.toJson()).toList()),
      );
      if (_activeProgramId != null) {
        await prefs.setString(_kActiveProgramIdKey, _activeProgramId!);
      } else {
        await prefs.remove(_kActiveProgramIdKey);
      }
      await prefs.setString(
        _kSessionsKey,
        RowingSession.encodeList(_sessions),
      );
      await prefs.setString(_kGeminiKey, _geminiApiKey);
      await prefs.setBool(_kNotificationsKey, _notificationsEnabled);
      final themeStr = switch (_themeMode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_kThemeModeKey, themeStr);
    } catch (e) {
      debugPrint('Persist fallback: $e');
    }
  }

  Future<void> setGeminiApiKey(String key) async {
    _geminiApiKey = key.trim();
    await _persist();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _persist();
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    if (_programs.isNotEmpty) {
      _programs[0] = _programs[0].copyWith(notificationsEnabled: enabled);
    }
    await _persist();
    notifyListeners();
  }

  // --- Gestion du Profil Unique ---

  Future<void> selectActiveUser(String userId) async {
    notifyListeners();
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    _user = profile;
    await _persist();
    notifyListeners();
  }

  UserProfile? getUserById(String? userId) => _user;

  // --- Gestion des Entraînements & Programmes ---

  Future<void> saveWorkout(Workout workout) async {
    final idx = _workouts.indexWhere((w) => w.id == workout.id);
    if (idx >= 0) {
      _workouts[idx] = workout;
    } else {
      _workouts.insert(0, workout);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> deleteWorkout(String workoutId) async {
    _workouts.removeWhere((w) => w.id == workoutId);
    await _persist();
    notifyListeners();
  }

  Future<void> saveProgram(TrainingProgram program) async {
    _notificationsEnabled = program.notificationsEnabled;
    if (_programs.isEmpty) {
      _programs = [program];
    } else {
      final idx = _programs.indexWhere((p) => p.id == program.id);
      if (idx >= 0) {
        _programs[idx] = program;
      } else {
        _programs.insert(0, program);
      }
    }
    for (final w in program.workouts.reversed) {
      if (!_workouts.any((existing) => existing.id == w.id)) {
        _workouts.insert(0, w);
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setActiveProgram(String programId) async {
    final idx = _programs.indexWhere((p) => p.id == programId);
    if (idx < 0 || activeProgram?.id == programId) return;
    _activeProgramId = programId;
    _notificationsEnabled = _programs[idx].notificationsEnabled;
    await _persist();
    notifyListeners();
  }

  Future<void> deleteProgram(String programId) async {
    _programs.removeWhere((p) => p.id == programId);
    if (_activeProgramId == programId) {
      _activeProgramId = _programs.isNotEmpty ? _programs.first.id : null;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> toggleWorkoutCompletionInProgram(
    String programId,
    String workoutId, {
    String? legacySessionKey,
  }) async {
    final idx = _programs.indexWhere((p) => p.id == programId);
    if (idx < 0) return;
    final prog = _programs[idx];
    final current = List<String>.from(prog.completedWorkoutIds);
    final hasWorkoutId = current.contains(workoutId);
    final hasLegacy =
        legacySessionKey != null && current.contains(legacySessionKey);

    if (hasWorkoutId || hasLegacy) {
      current.remove(workoutId);
      if (legacySessionKey != null) current.remove(legacySessionKey);
    } else {
      current.add(workoutId);
    }
    _programs[idx] = prog.copyWith(completedWorkoutIds: current);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleWorkoutCompletionInActiveProgram(String workoutId) async {
    final active = activeProgram;
    if (active == null) return;
    await toggleWorkoutCompletionInProgram(active.id, workoutId);
  }

  // --- Gestion des Sessions ---

  Future<void> addSession(RowingSession session) async {
    // Associe automatiquement au profil unique de l'application
    final assignedSession =
        session.isAssigned ? session : session.assignToUser(_user);
    _sessions.insert(0, assignedSession);

    // Si la session correspond à une séance du programme ou si un programme est en cours, met à jour l'avancement
    if (_programs.isNotEmpty) {
      final p = _programs[0];
      if (assignedSession.workoutId != null &&
          p.workouts.any((w) => w.id == assignedSession.workoutId) &&
          !p.completedWorkoutIds.contains(assignedSession.workoutId)) {
        _programs[0] = p.copyWith(
          completedWorkoutIds: [
            ...p.completedWorkoutIds,
            assignedSession.workoutId!,
          ],
        );
      } else if (assignedSession.workoutId == null) {
        // Marque la prochaine séance non complétée du programme si l'utilisateur a ramé
        final next = p.nextScheduledSession;
        if (next != null && !next.isCompleted) {
          _programs[0] = p.copyWith(
            completedWorkoutIds: [...p.completedWorkoutIds, next.id],
          );
        }
      }
    }

    await _persist();
    notifyListeners();
  }

  Future<void> assignSessionToUser(String sessionId, UserProfile user) async {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) return;
    _sessions[idx] = _sessions[idx].assignToUser(user);
    await _persist();
    notifyListeners();
  }

  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    await _persist();
    notifyListeners();
  }

  Future<RowingSession> syncConsoleSession({
    required double distanceMeters,
    required int currentResistance,
    int? durationSeconds,
    int? strokesCount,
    int? currentWatts,
    int? currentCadenceSpm,
    UserProfile? assignToUser,
  }) async {
    const estimatedSplitSec = 132.0;
    final durationSec = (durationSeconds != null && durationSeconds > 0)
        ? durationSeconds
        : ((distanceMeters / 500.0) * estimatedSplitSec).round().clamp(10, 7200);
    final avgSpm = (currentCadenceSpm != null && currentCadenceSpm > 0)
        ? currentCadenceSpm.toDouble()
        : 24.0;
    final avgWatts = (currentWatts != null && currentWatts > 0)
        ? currentWatts.toDouble()
        : (120.0 + (currentResistance * 4.5));
    final strokes = (strokesCount != null && strokesCount > 0)
        ? strokesCount
        : ((durationSec / 60.0) * avgSpm).round();

    final targetUser = assignToUser ?? _user;
    final kcal =
        (((0.048 * avgWatts + 1.19) * targetUser.weightKg * 3.5) / 200.0) *
            (durationSec / 60.0);

    final samples = <SessionSample>[];
    const sampleCount = 12;
    for (int i = 0; i <= sampleCount; i++) {
      final ratio = i / sampleCount;
      samples.add(
        SessionSample(
          elapsedSeconds: (durationSec * ratio).round(),
          watts: avgWatts.round(),
          cadenceSpm: avgSpm.round(),
          resistance: currentResistance,
          distanceMeters: distanceMeters * ratio,
          speedKmh: durationSec > 0 ? (distanceMeters / durationSec) * 3.6 : 0,
        ),
      );
    }

    final session = RowingSession(
      id: 'sync_console_${DateTime.now().millisecondsSinceEpoch}',
      userId: targetUser.id,
      workoutTitle: 'Séance Console Pro-Form',
      startedAt: DateTime.now().subtract(Duration(seconds: durationSec)),
      durationSeconds: durationSec,
      distanceMeters: distanceMeters,
      avgWatts: avgWatts,
      maxWatts: avgWatts.round(),
      avgCadenceSpm: avgSpm,
      avgResistance: currentResistance.toDouble(),
      caloriesKcal: kcal,
      strokesCount: strokes,
      source: SessionSource.lateSyncConsole,
      samples: samples,
      notes: 'Synchronisée en Bluetooth depuis la console Pro-Form Sport RL.',
    );

    await addSession(session);
    return session;
  }

  // --- Données par défaut au premier lancement ---

  static UserProfile _defaultSingleUser() {
    return UserProfile(
      id: 'user_matthieu',
      name: 'Matthieu',
      avatarEmoji: '🚣‍♂️',
      colorValue: 0xFF0284C7,
      weightKg: 78.0,
      heightCm: 180,
      age: 34,
      maxHeartRate: 186,
      level: FitnessLevel.intermediate,
      goal: WorkoutGoal.hiitWeightLoss,
      createdAt: DateTime.now(),
    );
  }

  static TrainingProgram _defaultProgram(
    UserProfile user,
    List<Workout> baseWorkouts,
  ) {
    final now = DateTime.now();
    // Créé il y a 3 jours pour montrer un planning réaliste avec rappel de prochaine session
    final created = now.subtract(const Duration(days: 3));
    final weeksCount = 4;
    final sessionsPerWeek = 3;
    final total = weeksCount * sessionsPerWeek;
    final progWorkouts = <Workout>[];
    for (int i = 0; i < total; i++) {
      final template = baseWorkouts[i % baseWorkouts.length];
      progWorkouts.add(
        Workout(
          id: 'prog_def_wk_${i + 1}',
          title: template.title,
          description: template.description,
          category: template.category,
          createdByUserId: user.id,
          isAiGenerated: true,
          steps: template.steps,
          createdAt: created,
        ),
      );
    }
    return TrainingProgram(
      id: 'prog_default_initial',
      title: 'Programme ${user.goal.label}',
      description:
          'Programme sur $weeksCount semaines ($sessionsPerWeek séances/semaine) adapté à ${user.name}.',
      userId: user.id,
      goal: user.goal,
      weeksCount: weeksCount,
      sessionsPerWeek: sessionsPerWeek,
      trainingDays: const [1, 3, 5],
      trainingTime: '18:30',
      notificationsEnabled: true,
      isAiGenerated: true,
      workouts: progWorkouts,
      completedWorkoutIds: const [],
      createdAt: created,
    );
  }

  static List<Workout> _defaultWorkouts() {
    final now = DateTime.now();
    return [
      Workout(
        id: 'wk_hiit_30_30',
        title: 'Fractionné 30/30 Explosif (SMR Auto)',
        description:
            'Alternance rapide entre sprints à haute résistance (Niv. 16-18) et récupération active (Niv. 6). Le rameur change la résistance automatiquement.',
        category: 'hiit',
        steps: const [
          WorkoutStep(
            id: 's1',
            title: 'Échauffement progressif',
            type: StepType.warmup,
            durationSeconds: 180,
            targetResistance: 6,
            targetSpmMin: 20,
            targetSpmMax: 23,
            targetWatts: 120,
            notes: 'Mise en route articulaire souple.',
          ),
          WorkoutStep(
            id: 's2',
            title: 'Sprint #1 (SMR 16)',
            type: StepType.work,
            durationSeconds: 30,
            targetResistance: 16,
            targetSpmMin: 28,
            targetSpmMax: 32,
            targetWatts: 220,
            notes: 'Poussée jambes maximale !',
          ),
          WorkoutStep(
            id: 's3',
            title: 'Récupération #1 (SMR 6)',
            type: StepType.rest,
            durationSeconds: 30,
            targetResistance: 6,
            targetSpmMin: 18,
            targetSpmMax: 21,
            targetWatts: 95,
          ),
          WorkoutStep(
            id: 's4',
            title: 'Sprint #2 (SMR 17)',
            type: StepType.work,
            durationSeconds: 30,
            targetResistance: 17,
            targetSpmMin: 28,
            targetSpmMax: 32,
            targetWatts: 230,
          ),
          WorkoutStep(
            id: 's5',
            title: 'Récupération #2 (SMR 6)',
            type: StepType.rest,
            durationSeconds: 30,
            targetResistance: 6,
            targetSpmMin: 18,
            targetSpmMax: 21,
            targetWatts: 95,
          ),
          WorkoutStep(
            id: 's6',
            title: 'Sprint #3 (SMR 18)',
            type: StepType.work,
            durationSeconds: 30,
            targetResistance: 18,
            targetSpmMin: 29,
            targetSpmMax: 33,
            targetWatts: 245,
          ),
          WorkoutStep(
            id: 's7',
            title: 'Récupération #3 (SMR 6)',
            type: StepType.rest,
            durationSeconds: 30,
            targetResistance: 6,
            targetSpmMin: 18,
            targetSpmMax: 21,
            targetWatts: 95,
          ),
          WorkoutStep(
            id: 's8',
            title: 'Sprint Final #4 (SMR 20)',
            type: StepType.work,
            durationSeconds: 30,
            targetResistance: 20,
            targetSpmMin: 30,
            targetSpmMax: 34,
            targetWatts: 260,
            notes: 'Donnez tout sur les 30 dernières secondes !',
          ),
          WorkoutStep(
            id: 's9',
            title: 'Retour au calme',
            type: StepType.cooldown,
            durationSeconds: 120,
            targetResistance: 4,
            targetSpmMin: 16,
            targetSpmMax: 20,
            targetWatts: 85,
          ),
        ],
        createdAt: now,
      ),
      Workout(
        id: 'wk_pyramid_smr',
        title: 'Pyramide Force SMR (Niv. 6 → 22 → 6)',
        description:
            'Montée progressive de la résistance magnétique par paliers de 2 minutes jusqu\'au niveau 22, puis redescente rapide en vélocité.',
        category: 'pyramid',
        steps: const [
          WorkoutStep(
            id: 'p1',
            title: 'Échauffement (SMR 6)',
            type: StepType.warmup,
            durationSeconds: 120,
            targetResistance: 6,
            targetSpmMin: 20,
            targetSpmMax: 22,
            targetWatts: 115,
          ),
          WorkoutStep(
            id: 'p2',
            title: 'Palier Montant 1 (SMR 10)',
            type: StepType.work,
            durationSeconds: 120,
            targetResistance: 10,
            targetSpmMin: 23,
            targetSpmMax: 25,
            targetWatts: 155,
          ),
          WorkoutStep(
            id: 'p3',
            title: 'Palier Montant 2 (SMR 15)',
            type: StepType.work,
            durationSeconds: 120,
            targetResistance: 15,
            targetSpmMin: 24,
            targetSpmMax: 26,
            targetWatts: 185,
          ),
          WorkoutStep(
            id: 'p4',
            title: 'Sommet Force Max (SMR 22)',
            type: StepType.work,
            durationSeconds: 90,
            targetResistance: 22,
            targetSpmMin: 22,
            targetSpmMax: 25,
            targetWatts: 235,
            notes: 'Gainage abdominal fort, poussée puissante !',
          ),
          WorkoutStep(
            id: 'p5',
            title: 'Palier Descendant (SMR 12)',
            type: StepType.work,
            durationSeconds: 120,
            targetResistance: 12,
            targetSpmMin: 26,
            targetSpmMax: 28,
            targetWatts: 175,
          ),
          WorkoutStep(
            id: 'p6',
            title: 'Retour au calme (SMR 4)',
            type: StepType.cooldown,
            durationSeconds: 120,
            targetResistance: 4,
            targetSpmMin: 18,
            targetSpmMax: 20,
            targetWatts: 90,
          ),
        ],
        createdAt: now,
      ),
      Workout(
        id: 'wk_endurance_20',
        title: 'Endurance Fondamentale & Cardio (20 min)',
        description:
            'Séance aérobie régulière avec légères variations de résistance (SMR 8 à 12) pour brûler les graisses sans épuisement.',
        category: 'endurance',
        steps: const [
          WorkoutStep(
            id: 'e1',
            title: 'Mise en rythme (SMR 7)',
            type: StepType.warmup,
            durationSeconds: 180,
            targetResistance: 7,
            targetSpmMin: 20,
            targetSpmMax: 22,
            targetWatts: 125,
          ),
          WorkoutStep(
            id: 'e2',
            title: 'Croisière Tempo 1 (SMR 10)',
            type: StepType.work,
            durationSeconds: 420,
            targetResistance: 10,
            targetSpmMin: 23,
            targetSpmMax: 25,
            targetWatts: 155,
          ),
          WorkoutStep(
            id: 'e3',
            title: 'Croisière Tempo 2 (SMR 12)',
            type: StepType.work,
            durationSeconds: 420,
            targetResistance: 12,
            targetSpmMin: 24,
            targetSpmMax: 26,
            targetWatts: 170,
          ),
          WorkoutStep(
            id: 'e4',
            title: 'Retour au calme (SMR 5)',
            type: StepType.cooldown,
            durationSeconds: 180,
            targetResistance: 5,
            targetSpmMin: 18,
            targetSpmMax: 20,
            targetWatts: 95,
          ),
        ],
        createdAt: now,
      ),
    ];
  }
}

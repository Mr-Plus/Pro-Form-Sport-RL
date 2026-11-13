import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/models.dart';
import '../services/app_state_service.dart';
import '../services/live_session_service.dart';
import '../services/proform_ble_service.dart';
import '../services/voice_coach_service.dart';
import '../theme/app_theme.dart';

class LandscapeSessionScreen extends StatefulWidget {
  final AppStateService appState;
  final ProFormBleService bleService;
  final VoiceCoachService voiceCoach;
  final LiveSessionService liveSession;
  final Workout? selectedWorkout;
  final VoidCallback onClearWorkout;
  final VoidCallback onSessionSaved;

  const LandscapeSessionScreen({
    super.key,
    required this.appState,
    required this.bleService,
    required this.voiceCoach,
    required this.liveSession,
    required this.selectedWorkout,
    required this.onClearWorkout,
    required this.onSessionSaved,
  });

  @override
  State<LandscapeSessionScreen> createState() => _LandscapeSessionScreenState();
}

class _LandscapeSessionScreenState extends State<LandscapeSessionScreen> {
  LiveSessionService get live => widget.liveSession;

  @override
  void initState() {
    super.initState();
    // Maintien de l'écran éveillé en mode paysage (pas de mise en veille)
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _stopAndSaveSession() {
    final summary = widget.liveSession.stopAndBuildSummary();
    if (summary == null) {
      widget.liveSession.resetAfterSaveOrDiscard();
      return;
    }

    final user = widget.appState.activeUser;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          'ENREGISTRER LA SESSION',
          style: AppTypography.bebasTitle(fontSize: 22),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.workout?.title ?? 'Session Libre',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '• Durée : ${_formatTime(summary.durationSeconds)}\n• Distance : ${summary.distanceMeters.round()} m\n• Puissance : ${summary.avgWatts.round()} W (Max ${summary.maxWatts} W)\n• Cadence : ${summary.avgSpm.round()} SPM\n• Coups de rame : ${summary.strokesCount}\n• Calories : ${summary.caloriesKcal.round()} kcal',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.liveSession.resetAfterSaveOrDiscard();
            },
            child: const Text('Ignorer'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await widget.appState.addSession(
                summary.toWorkoutSession(user.id),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              widget.liveSession.resetAfterSaveOrDiscard();
              widget.onSessionSaved();
            },
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.appState,
        widget.bleService,
        widget.voiceCoach,
        widget.liveSession,
      ]),
      builder: (context, _) {
        final tel = widget.bleService.latestTelemetry;
        final live = widget.liveSession;
        final currentRes = tel.resistanceLevel.clamp(1, 24);

        // Récupération en priorité des valeurs réelles de séance
        final activeDist = live.isRunning
            ? live.sessionDistanceMeters
            : (live.sessionDistanceMeters > 0
                ? live.sessionDistanceMeters
                : (tel.distanceMeters < 60000 ? tel.distanceMeters : 0.0));

        final activeStrokes = live.isRunning
            ? live.sessionStrokesCount
            : (live.sessionStrokesCount > 0
                ? live.sessionStrokesCount
                : (tel.strokesCount < 60000 ? tel.strokesCount : 0));

        final activeElapsed = live.isRunning
            ? live.sessionElapsedSeconds
            : (live.sessionElapsedSeconds > 0
                ? live.sessionElapsedSeconds
                : (tel.elapsedSeconds < 60000 ? tel.elapsedSeconds : 0));

        final activeCal = live.isRunning
            ? live.sessionCalories
            : (live.sessionCalories > 0
                ? live.sessionCalories
                : (tel.caloriesKcal < 60000 ? tel.caloriesKcal : 0.0));

        return Scaffold(
          backgroundColor: AppColors.level0,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  // Barre d'actions supérieure compacte
                  _buildHeaderBar(),
                  const SizedBox(height: 8),

                  // Grille 2 Lignes x 4 Colonnes donnant toute la priorité aux données
                  Expanded(
                    child: Column(
                      children: [
                        // Ligne 1 : Durée, Allure (/500m), Puissance (W), Cadence (SPM)
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _MetricBox(
                                  label: 'DURÉE',
                                  value: _formatTime(activeElapsed),
                                  unit: '',
                                  accentColor: live.isPaused ? AppColors.amber : AppColors.primary,
                                  icon: Icons.timer_outlined,
                                  isTime: true,
                                  isPaused: live.isPaused,
                                  pauseDuration: live.isPaused
                                      ? _formatTime(live.pauseElapsedSeconds)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _MetricBox(
                                  label: 'ALLURE',
                                  value: tel.formattedSplit500m,
                                  unit: '/500m',
                                  accentColor: AppColors.rose,
                                  icon: Icons.speed_rounded,
                                  isHighlighted: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _MetricBox(
                                  label: 'PUISSANCE',
                                  value: '${tel.watts}',
                                  unit: 'W',
                                  accentColor: AppColors.orange,
                                  icon: Icons.bolt_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _MetricBox(
                                  label: 'CADENCE',
                                  value: '${tel.cadenceSpm}',
                                  unit: 'coups/min',
                                  accentColor: AppColors.purple,
                                  icon: Icons.autorenew_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Ligne 2 : Distance (m), Coups de rame, Calories (kcal), Résistance (/24)
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _MetricBox(
                                  label: 'DISTANCE',
                                  value: '${activeDist.round()}',
                                  unit: 'm',
                                  accentColor: AppColors.primary,
                                  icon: Icons.straighten_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _MetricBox(
                                  label: 'COUPS DE RAME',
                                  value: '$activeStrokes',
                                  unit: 'coups',
                                  accentColor: AppColors.amber,
                                  icon: Icons.waves_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _MetricBox(
                                  label: 'CALORIES',
                                  value: '${activeCal.round()}',
                                  unit: 'kcal',
                                  accentColor: AppColors.red,
                                  icon: Icons.local_fire_department_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _MetricBox(
                                  label: 'RÉSISTANCE SMR',
                                  value: '$currentRes',
                                  unit: '/ 24',
                                  accentColor: const Color(0xFF2DD4BF),
                                  icon: Icons.tune_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderBar() {
    final wk = widget.selectedWorkout;
    final step = (wk != null && live.currentStepIndex < wk.steps.length)
        ? wk.steps[live.currentStepIndex]
        : null;

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.level1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icône Aviron
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.rose.withValues(alpha: 0.18),
            ),
            child: Icon(
              Icons.rowing_rounded,
              color: AppColors.rosePastel,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),

          // Bloc Titre + Étape du programme sur 2 lignes distinctes en flex-shrink
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ligne 1 : Titre de la séance
                Text(
                  wk != null ? wk.title : 'Séance Libre',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),

                // Ligne 2 : Étape du programme & tag Pause
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (step != null)
                      Flexible(
                        child: Text(
                          'Étape ${live.currentStepIndex + 1}/${wk!.steps.length} : ${step.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.rosePastel,
                          ),
                        ),
                      )
                    else
                      Text(
                        'Séance libre',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    if (live.isPaused) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.amber.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pause_circle_rounded,
                              size: 11,
                              color: AppColors.amber,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'EN PAUSE (${_formatTime(live.pauseElapsedSeconds)})',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.amber,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Contrôles garantis de rester TOUJOURS à l'écran (Row compact sans expansion)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Prêt (auto-start dès le 1er coup de rame) / Pause / Reprendre / Arrêter
              if (!live.isRunning)
                widget.bleService.isHardwareConnected
                    ? Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                            color: AppColors.green.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.rowing_rounded,
                                size: 17, color: AppColors.green),
                            const SizedBox(width: 6),
                            Text(
                              'Prêt — ramez pour démarrer',
                              style: TextStyle(
                                color: AppColors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SizedBox(
                        height: 38,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.green,
                            side: BorderSide(
                              color: AppColors.green.withValues(alpha: 0.85),
                              width: 1.6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(19),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          onPressed: () => live.startSession(auto: false),
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text(
                            'DÉMARRER',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      )
              else ...[
                SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          live.isPaused ? AppColors.amber : AppColors.rose,
                      side: BorderSide(
                        color: (live.isPaused ? AppColors.amber : AppColors.rose)
                            .withValues(alpha: 0.85),
                        width: 1.6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(19),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: live.togglePause,
                    icon: Icon(
                      live.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      size: 18,
                    ),
                    label: Text(
                      live.isPaused ? 'REPRENDRE' : 'PAUSE',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 38,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(19),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: _stopAndSaveSession,
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: const Text(
                      'ARRÊTER',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),

              // Coach Vocal Toggle Button
              Tooltip(
                message: widget.voiceCoach.isEnabled
                    ? 'Coach vocal actif'
                    : 'Coach vocal muet',
                child: InkWell(
                  borderRadius: BorderRadius.circular(19),
                  onTap: () => widget.voiceCoach.toggleEnabled(),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: widget.voiceCoach.isEnabled
                          ? AppColors.rose.withValues(alpha: 0.16)
                          : AppColors.level2,
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(
                        color: widget.voiceCoach.isEnabled
                            ? AppColors.rose.withValues(alpha: 0.45)
                            : Colors.white.withValues(alpha: 0.08),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.voiceCoach.isEnabled
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          size: 16,
                          color: widget.voiceCoach.isEnabled
                              ? AppColors.rosePastel
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.voiceCoach.isEnabled ? 'Coach' : 'Muet',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: widget.voiceCoach.isEnabled
                                ? AppColors.rosePastel
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Bouton Rotation Portrait
              Tooltip(
                message: 'Basculer en mode portrait',
                child: InkWell(
                  borderRadius: BorderRadius.circular(19),
                  onTap: () {
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.portraitUp,
                      DeviceOrientation.portraitDown,
                    ]);
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.level2,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.screen_rotation_rounded,
                      size: 18,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color accentColor;
  final IconData? icon;
  final bool isTime;
  final bool isHighlighted;
  final bool isPaused;
  final String? pauseDuration;

  const _MetricBox({
    required this.label,
    required this.value,
    required this.unit,
    required this.accentColor,
    this.icon,
    this.isTime = false,
    this.isHighlighted = false,
    this.isPaused = false,
    this.pauseDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlighted
            ? accentColor.withValues(alpha: 0.12)
            : AppColors.level1,
        borderRadius: BorderRadius.circular(14),
        border: isHighlighted
            ? Border.all(
                color: accentColor.withValues(alpha: 0.8),
                width: 1.5,
              )
            : isPaused && isTime
                ? Border.all(
                    color: AppColors.amber.withValues(alpha: 0.8),
                    width: 1.5,
                  )
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 13,
                        color: isHighlighted ? accentColor : const Color(0xFF8A99AD),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isHighlighted ? accentColor : const Color(0xFF8A99AD),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isTime && isPaused) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pause_circle_filled_rounded,
                        size: 10,
                        color: AppColors.amber,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        pauseDuration != null
                            ? 'PAUSE $pauseDuration'
                            : 'PAUSE',
                        style: TextStyle(
                          color: AppColors.amber,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontFamily: isTime ? 'monospace' : null,
                        fontSize: isTime ? 32 : 36,
                        fontWeight: FontWeight.w900,
                        color: isPaused && isTime
                            ? AppColors.amber
                            : isHighlighted
                                ? accentColor
                                : Colors.white,
                        letterSpacing: isTime ? 1.0 : -0.5,
                        height: 1.0,
                      ),
                    ),
                    if (isTime && isPaused && pauseDuration != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(pause $pauseDuration)',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: AppColors.amber.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        unit,
                        style: TextStyle(
                          color: isHighlighted
                              ? accentColor.withValues(alpha: 0.85)
                              : const Color(0xFF8A99AD),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

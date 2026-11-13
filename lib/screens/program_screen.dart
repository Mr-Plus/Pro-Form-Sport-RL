import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/ai_coach_service.dart';
import '../services/app_state_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/telemetry_charts.dart';

class ProgramScreen extends StatefulWidget {
  final AppStateService appState;
  final Workout? selectedWorkoutForLandscape;
  final ValueChanged<Workout> onSelectWorkoutForLandscape;

  const ProgramScreen({
    super.key,
    required this.appState,
    this.selectedWorkoutForLandscape,
    required this.onSelectWorkoutForLandscape,
  });

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  String? _openedProgramId;

  TrainingProgram? _findProgram(String? id) {
    if (id == null) return null;
    for (final p in widget.appState.programs) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final opened = _findProgram(_openedProgramId);
        if (opened != null) {
          return _buildProgramDetail(context, opened);
        }
        return _buildProgramsList(context);
      },
    );
  }

  // ===========================================================================
  // 1. LISTE DES PROGRAMMES
  // ===========================================================================

  Widget _buildProgramsList(BuildContext context) {
    final programs = widget.appState.programs;
    final activeId = widget.appState.activeProgram?.id;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.pageTop,
        AppSpacing.pageHorizontal,
        95,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'MES PROGRAMMES',
                style: AppTypography.h1(fontSize: 22),
              ),
            ),
            FilledButton.icon(
              style: AppButtons.compact(),
              onPressed: () => _showCreateOrEditProgramModal(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouveau'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.headerGap),
        if (programs.isEmpty)
          _buildEmptyProgramsState(context)
        else
          ...programs.map((prog) {
            final isActive = prog.id == activeId;
            final pct = prog.progressPercent;
            final done = prog.completedWorkoutIds.length;
            final total = prog.workouts.length;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: AppCards.cardDecoration(
                radius: AppSpacing.cardRadius,
                border: isActive
                    ? Border.all(
                        color: AppColors.rose.withValues(alpha: 0.7),
                        width: 1.5,
                      )
                    : null,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                onTap: () => setState(() => _openedProgramId = prog.id),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    prog.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (isActive) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: AppCards.tagDecoration(),
                                    child: Text(
                                      'ACTIF',
                                      style: TextStyle(
                                        color: AppColors.rosePastel,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$pct%',
                            style: AppTypography.metric(
                              color: AppColors.rose,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: prog.progressRatio,
                          minHeight: 7,
                          backgroundColor: AppColors.level2,
                          color: AppColors.rose,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$done/$total séances • ${prog.formattedDaysSummary} à ${prog.trainingTime}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: isActive
                                ? 'Programme actif'
                                : 'Sélectionner ce programme',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              isActive
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 22,
                              color: isActive
                                  ? AppColors.rose
                                  : AppColors.textSecondary,
                            ),
                            onPressed: () =>
                                widget.appState.setActiveProgram(prog.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildEmptyProgramsState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: AppCards.cardDecoration(radius: AppSpacing.cardRadius),
      child: Column(
        children: [
          Icon(
            Icons.calendar_month_rounded,
            size: 46,
            color: AppColors.rose,
          ),
          const SizedBox(height: 16),
          Text(
            'AUCUN PROGRAMME',
            style: AppTypography.h2(
              color: AppColors.textPrimary,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Créez un programme, nommez-le, puis glissez-déposez vos séances pour construire votre calendrier.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: AppButtons.primary(),
            onPressed: () => _showCreateOrEditProgramModal(context),
            icon: const Icon(Icons.add, size: 19),
            label: const Text('Créer un programme'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. DÉTAIL D'UN PROGRAMME (CALENDRIER + 8 MODÈLES GLISSER-DÉPOSER)
  // ===========================================================================

  Widget _buildProgramDetail(BuildContext context, TrainingProgram prog) {
    final schedule = prog.buildSchedule();
    final nextSession = prog.nextScheduledSession;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        12,
        AppSpacing.pageHorizontal,
        95,
      ),
      children: [
        // En-tête retour + titre + réglages
        Row(
          children: [
            IconButton(
              tooltip: 'Retour aux programmes',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _openedProgramId = null),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
            Expanded(
              child: Text(
                prog.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.h2(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Planification
        Text(
          'PLANIFICATION',
          style: AppTypography.bebasSection(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: AppCards.cardDecoration(radius: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${prog.formattedDaysSummary} à ${prog.trainingTime}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Modifier la planification',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    _showCreateOrEditProgramModal(context, existing: prog),
                icon: const Icon(Icons.tune_rounded, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Calendrier des séances
        Text(
          'CALENDRIER (${schedule.length} SÉANCES)',
          style: AppTypography.bebasSection(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),

        if (schedule.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 28,
            ),
            decoration: AppCards.subCardDecoration(radius: 16),
            child: Column(
              children: [
                Icon(
                  Icons.event_note_rounded,
                  color: AppColors.textMuted,
                  size: 30,
                ),
                const SizedBox(height: 8),
                Text(
                  'Aucune séance planifiée.\nTouchez "Ajouter une séance" ci-dessous pour choisir un modèle.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: schedule.length,
            onReorderItem: (oldIndex, newIndex) =>
                _reorderWorkout(prog, oldIndex, newIndex),
            itemBuilder: (context, idx) {
              final item = schedule[idx];
              final isNext =
                  nextSession?.id == item.id && !item.isCompleted;
              return _buildScheduledSessionRow(
                context,
                prog,
                item,
                idx,
                isNext: isNext,
              );
            },
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: AppButtons.primary(),
            onPressed: () => _showTemplatePickerSheet(context, prog),
            icon: const Icon(Icons.add, size: 19),
            label: const Text(
              'Ajouter une séance',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: BorderSide(color: AppColors.red.withValues(alpha: 0.45)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => _confirmDeleteProgram(context, prog),
            icon: const Icon(Icons.delete_outline, size: 19),
            label: const Text(
              'Supprimer le programme',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduledSessionRow(
    BuildContext context,
    TrainingProgram prog,
    ScheduledProgramSession item,
    int index, {
    required bool isNext,
  }) {
    final wk = item.workout;
    final minRes = wk.steps.isEmpty
        ? 1
        : wk.steps.map((s) => s.targetResistance).reduce(min);
    final maxRes = wk.steps.isEmpty
        ? 1
        : wk.steps.map((s) => s.targetResistance).reduce(max);
    final dateLabel = _formatSessionDate(item.scheduledDateTime);

    return Container(
      key: ValueKey('${wk.id}_$index'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: AppCards.subCardDecoration(radius: 14),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => widget.appState.toggleWorkoutCompletionInProgram(
              prog.id,
              wk.id,
              legacySessionKey: item.id,
            ),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: item.isCompleted ? AppColors.rose : AppColors.level2,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: item.isCompleted
                      ? AppColors.rose
                      : AppColors.textMuted.withValues(alpha: 0.4),
                ),
              ),
              child: item.isCompleted
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      dateLabel,
                      style: TextStyle(
                        color: isNext
                            ? AppColors.rosePastel
                            : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isNext) ...[
                      const SizedBox(width: 6),
                      Text(
                        '• PROCHAINE',
                        style: TextStyle(
                          color: AppColors.rose,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _cleanWorkoutTitle(wk.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    decoration:
                        item.isCompleted ? TextDecoration.lineThrough : null,
                    color: item.isCompleted
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${wk.formattedDuration} • SMR $minRes–$maxRes',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Modifier la séance',
            visualDensity: VisualDensity.compact,
            onPressed: () => _showEditWorkoutModal(context, prog, index, wk),
            icon: Icon(
              Icons.edit_outlined,
              size: 19,
              color: AppColors.rosePastel,
            ),
          ),
          IconButton(
            tooltip: 'Supprimer du programme',
            visualDensity: VisualDensity.compact,
            onPressed: () => _removeWorkoutFromProgram(prog, index),
            icon: Icon(
              Icons.delete_outline,
              size: 19,
              color: AppColors.red,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ACTIONS & MODALES
  // ===========================================================================

  void _launchWorkout(BuildContext context, Workout wk) {
    widget.onSelectWorkoutForLandscape(wk);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Séance "${wk.title}" prête ! Passez en mode paysage pour démarrer.',
        ),
      ),
    );
  }

  Future<void> _reorderWorkout(
    TrainingProgram prog,
    int oldIndex,
    int newIndex,
  ) async {
    final list = List<Workout>.from(prog.workouts);
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);

    final updated = prog.copyWith(workouts: list);
    await widget.appState.saveProgram(updated);
  }

  Future<void> _removeWorkoutFromProgram(
    TrainingProgram prog,
    int index,
  ) async {
    final list = List<Workout>.from(prog.workouts);
    final removed = list.removeAt(index);
    final updatedCompleted = List<String>.from(prog.completedWorkoutIds)
      ..remove(removed.id);

    final updated = prog.copyWith(
      workouts: list,
      completedWorkoutIds: updatedCompleted,
    );
    await widget.appState.saveProgram(updated);
  }

  void _confirmDeleteProgram(BuildContext context, TrainingProgram prog) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le programme ?'),
        content: Text(
          'Attention : cette action est irréversible. Voulez-vous vraiment supprimer "${prog.title}" et tout son calendrier ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.appState.deleteProgram(prog.id);
              if (_openedProgramId == prog.id && mounted) {
                setState(() => _openedProgramId = null);
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showTemplatePickerSheet(BuildContext context, TrainingProgram prog) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (context, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            Text(
              'CHOISIR UN MODÈLE DE SÉANCE',
              style: AppTypography.h2(
                color: AppColors.textPrimary,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 14),
            ...WorkoutTemplateType.values.map(
              (tpl) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: AppCards.subCardDecoration(radius: 14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showConfigureTemplateModal(context, prog, tpl);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: AppCards.tagDecoration(),
                          child: Icon(
                            _templateIcon(tpl),
                            size: 19,
                            color: AppColors.rosePastel,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tpl.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tpl.subtitle,
                                style: TextStyle(
                                  color: AppColors.rosePastel,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tpl.benefit,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMinutesValue(int seconds) {
    if (seconds % 60 == 0) return '${seconds ~/ 60}';
    final s = (seconds / 60.0).toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  void _showEditWorkoutModal(
    BuildContext context,
    TrainingProgram prog,
    int workoutIndex,
    Workout workout,
  ) {
    final titleCtrl = TextEditingController(
      text: _cleanWorkoutTitle(workout.title),
    );
    final steps = workout.steps.map((s) => s.copyWith()).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final totalSec =
              steps.fold<int>(0, (sum, e) => sum + e.durationSeconds);

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.94,
            minChildSize: 0.55,
            builder: (context, scrollCtrl) => ListView(
              controller: scrollCtrl,
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'MODIFIER LA SÉANCE',
                        style: AppTypography.h2(
                          color: AppColors.textPrimary,
                          fontSize: 19,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la séance',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'BLOCS (${totalSec ~/ 60}m ${totalSec % 60}s • ${steps.length} blocs)',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        setModalState(() {
                          steps.add(
                            WorkoutStep(
                              id: 'step_${DateTime.now().microsecondsSinceEpoch}',
                              title: 'Effort #${steps.length + 1}',
                              type: StepType.work,
                              durationSeconds: 60,
                              targetResistance: 12,
                              targetSpmMin: 24,
                              targetSpmMax: 28,
                            ),
                          );
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 17),
                      label: const Text('Ajouter un bloc'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...List.generate(steps.length, (idx) {
                  final s = steps[idx];
                  return Container(
                    key: ValueKey(s.id),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: AppCards.subCardDecoration(radius: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButton<StepType>(
                            value: s.type,
                            isExpanded: true,
                            isDense: true,
                            underline: const SizedBox.shrink(),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                            items: StepType.values
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(
                                      t.label,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: stepTypeColor(t),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setModalState(() {
                                  steps[idx] = s.copyWith(
                                    type: v,
                                    title: v.label,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 82,
                          child: TextFormField(
                            initialValue:
                                _formatMinutesValue(s.durationSeconds),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Durée',
                              labelStyle: TextStyle(fontSize: 11),
                              suffixText: 'min',
                              suffixStyle: TextStyle(fontSize: 11),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 7,
                              ),
                            ),
                            onChanged: (v) {
                              final parsed =
                                  double.tryParse(v.replaceAll(',', '.'));
                              if (parsed != null && parsed > 0) {
                                setModalState(() {
                                  steps[idx] = s.copyWith(
                                    durationSeconds:
                                        (parsed * 60).round().clamp(1, 7200),
                                  );
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 84,
                          child: TextFormField(
                            initialValue: '${s.targetResistance}',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.orange,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Résistance',
                              labelStyle: TextStyle(fontSize: 11),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 7,
                              ),
                            ),
                            onChanged: (v) {
                              final parsed = int.tryParse(v);
                              if (parsed != null && parsed >= 1) {
                                setModalState(() {
                                  steps[idx] = s.copyWith(
                                    targetResistance: parsed.clamp(1, 24),
                                  );
                                });
                              }
                            },
                          ),
                        ),
                        if (steps.length > 1) ...[
                          const SizedBox(width: 2),
                          IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.red,
                            ),
                            onPressed: () =>
                                setModalState(() => steps.removeAt(idx)),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: AppButtons.primary(),
                  onPressed: () async {
                    final updatedWorkout = workout.copyWith(
                      title: titleCtrl.text.trim().isEmpty
                          ? _cleanWorkoutTitle(workout.title)
                          : titleCtrl.text.trim(),
                      steps: steps,
                    );
                    final updatedList = List<Workout>.from(prog.workouts);
                    updatedList[workoutIndex] = updatedWorkout;
                    await widget.appState.saveProgram(
                      prog.copyWith(workouts: updatedList),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text(
                    'Enregistrer les modifications',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showConfigureTemplateModal(
    BuildContext context,
    TrainingProgram prog,
    WorkoutTemplateType template,
  ) {
    int durationMinutes = 25;
    final durationCtrl = TextEditingController(text: '25');
    String intensity = 'moderee';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: AppCards.tagDecoration(),
                    child: Icon(
                      _templateIcon(template),
                      color: AppColors.rosePastel,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.label,
                          style: AppTypography.h2(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          template.subtitle,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'DURÉE (MINUTES)',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: [15, 20, 30, 45].map((m) {
                        final selected = durationMinutes == m;
                        return ChoiceChip(
                          label: Text('$m min'),
                          selected: selected,
                          onSelected: (_) => setModalState(() {
                            durationMinutes = m;
                            durationCtrl.text = '$m';
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 76,
                    child: TextField(
                      controller: durationCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        suffixText: 'm',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null && parsed >= 5) {
                          setModalState(
                            () => durationMinutes = parsed.clamp(5, 120),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'COMPLEXITÉ / INTENSITÉ',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  ('douce', 'Douce'),
                  ('moderee', 'Modérée'),
                  ('intense', 'Intense'),
                  ('maximale', 'Maximale'),
                ].map((opt) {
                  final selected = intensity == opt.$1;
                  return ChoiceChip(
                    label: Text(opt.$2),
                    selected: selected,
                    onSelected: (_) => setModalState(() => intensity = opt.$1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: AppButtons.primary(),
                onPressed: () async {
                  final workout = AiCoachService.buildWorkoutFromTemplate(
                    template: template,
                    durationMinutes: durationMinutes,
                    intensity: intensity,
                    user: widget.appState.activeUser,
                    userHistory: widget.appState.sessions,
                  );
                  final updatedWorkouts = [...prog.workouts, workout];
                  await widget.appState.saveProgram(
                    prog.copyWith(workouts: updatedWorkouts),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.add),
                label: const Text(
                  'Ajouter au programme',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateOrEditProgramModal(
    BuildContext context, {
    TrainingProgram? existing,
  }) {
    final nameCtrl = TextEditingController(
      text: existing?.title ?? 'Mon Programme',
    );
    final selectedDays = List<int>.from(existing?.trainingDays ?? [1, 3, 5]);
    final timeParts = (existing?.trainingTime ?? '18:30').split(':');
    TimeOfDay selectedTime = TimeOfDay(
      hour: int.tryParse(timeParts[0]) ?? 18,
      minute: int.tryParse(timeParts.length > 1 ? timeParts[1] : '30') ?? 30,
    );
    bool notifEnabled = existing?.notificationsEnabled ?? true;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final timeStr =
              '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null
                      ? 'NOUVEAU PROGRAMME'
                      : 'PARAMÈTRES DU PROGRAMME',
                  style: AppTypography.h2(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom du programme',
                    hintText: 'Ex: Remise en forme, Objectif 2000m...',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'JOURS D\'ENTRAÎNEMENT',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(7, (idx) {
                    final dayNum = idx + 1;
                    final isSel = selectedDays.contains(dayNum);
                    return FilterChip(
                      label: Text(TrainingProgram.weekdayShortName(dayNum)),
                      selected: isSel,
                      onSelected: (val) {
                        setModalState(() {
                          if (val) {
                            selectedDays.add(dayNum);
                            selectedDays.sort();
                          } else if (selectedDays.length > 1) {
                            selectedDays.remove(dayNum);
                          }
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setModalState(() => selectedTime = picked);
                          }
                        },
                        icon: const Icon(Icons.schedule_rounded, size: 18),
                        label: Text('Heure : $timeStr'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        const Text('Rappels', style: TextStyle(fontSize: 13)),
                        Switch(
                          value: notifEnabled,
                          onChanged: (v) =>
                              setModalState(() => notifEnabled = v),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: AppButtons.primary(),
                  onPressed: () async {
                    final title = nameCtrl.text.trim().isEmpty
                        ? 'Mon Programme'
                        : nameCtrl.text.trim();
                    final days = List<int>.from(selectedDays)..sort();

                    final program = existing != null
                        ? existing.copyWith(
                            title: title,
                            trainingDays: days,
                            sessionsPerWeek: days.length,
                            trainingTime: timeStr,
                            notificationsEnabled: notifEnabled,
                          )
                        : TrainingProgram(
                            id: 'prog_${DateTime.now().millisecondsSinceEpoch}',
                            title: title,
                            description: 'Programme personnalisé',
                            userId: widget.appState.activeUser.id,
                            weeksCount: 4,
                            sessionsPerWeek: days.length,
                            trainingDays: days,
                            trainingTime: timeStr,
                            notificationsEnabled: notifEnabled,
                            isAiGenerated: false,
                            workouts: const [],
                            createdAt: DateTime.now(),
                          );

                    await widget.appState.saveProgram(program);
                    await NotificationService.instance.cancelAll();
                    if (program.notificationsEnabled) {
                      final next = program.nextScheduledSession;
                      if (next != null) {
                        await NotificationService.instance
                            .scheduleSessionReminder(
                          id: 1001,
                          scheduledDate: next.scheduledDateTime,
                          title: 'Séance Rameur • ${program.title}',
                          body: 'C\'est l\'heure : ${next.workout.title}',
                        );
                      }
                    }

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (existing == null && mounted) {
                      setState(() => _openedProgramId = program.id);
                    }
                  },
                  child: Text(
                    existing == null ? 'Créer et ajouter des séances' : 'Enregistrer',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatSessionDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = d.difference(today).inDays;
    final hhmm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (diff == 0) return "Aujourd'hui • $hhmm";
    if (diff == 1) return 'Demain • $hhmm';
    final dayLabel = DateFormat('EEE d MMM', 'fr_FR').format(dt);
    return '$dayLabel • $hhmm';
  }
}

IconData _templateIcon(WorkoutTemplateType tpl) {
  return switch (tpl) {
    WorkoutTemplateType.endurance => Icons.favorite_outline_rounded,
    WorkoutTemplateType.tempo => Icons.speed_rounded,
    WorkoutTemplateType.longIntervals => Icons.trending_up_rounded,
    WorkoutTemplateType.hiit => Icons.bolt_rounded,
    WorkoutTemplateType.pyramid => Icons.change_history_rounded,
    WorkoutTemplateType.strength => Icons.fitness_center_rounded,
    WorkoutTemplateType.timeTrial => Icons.timer_outlined,
    WorkoutTemplateType.recovery => Icons.spa_outlined,
  };
}

String _cleanWorkoutTitle(String title) {
  return title.replaceFirst(RegExp(r'^S\d+\.\d+\s*•\s*'), '');
}

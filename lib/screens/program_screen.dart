import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/app_state_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/telemetry_charts.dart';

class ProgramScreen extends StatefulWidget {
  final AppStateService appState;
  final ValueChanged<Workout> onSelectWorkoutForLandscape;

  const ProgramScreen({
    super.key,
    required this.appState,
    required this.onSelectWorkoutForLandscape,
  });

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final prog = widget.appState.activeProgram;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.pageTop,
            AppSpacing.pageHorizontal,
            95,
          ),
          children: [
            // En-tête : Titre & Action
            Row(
              children: [
                Expanded(
                  child: Text(
                    'PROGRAMME EN COURS',
                    style: AppTypography.h1(fontSize: 22),
                  ),
                ),
                if (prog != null)
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.level1,
                      foregroundColor: AppColors.textPrimary,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showProgramEditorModal(context, existing: prog),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Modifier'),
                  )
                else
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rose,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showProgramEditorModal(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Créer'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.headerGap),

            if (prog == null)
              _buildEmptyState(context)
            else ...[
              // 1. Carte de progression du programme
              _buildProgressCard(context, prog),
              const SizedBox(height: AppSpacing.sectionGap),

              // 2. Planning hebdomadaire des séances
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'PLANNING DES SÉANCES',
                    style: AppTypography.h3(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: AppCards.tagDecoration(),
                    child: Text(
                      '${prog.formattedDaysSummary} • ${prog.trainingTime}',
                      style: TextStyle(
                        color: AppColors.rosePastel,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._buildWeeklyScheduleWidgets(context, prog),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: AppCards.cardDecoration(radius: AppSpacing.cardRadius),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.rose.withValues(alpha: 0.15),
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              size: 44,
              color: AppColors.rose,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'AUCUN PROGRAMME EN COURS',
            style: AppTypography.h2(
              color: AppColors.textPrimary,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Choisissez votre objectif, le nombre de semaines et vos jours d\'entraînement pour structurer vos séances avec votre rameur.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => _showProgramEditorModal(context),
            icon: const Icon(Icons.add),
            label: const Text(
              'Créer mon programme',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, TrainingProgram prog) {
    final pct = prog.progressPercent;
    final doneCount = prog.completedWorkoutIds.length;
    final totalCount = prog.workouts.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: AppCards.cardDecoration(radius: AppSpacing.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prog.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h2(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${prog.goal.label} • ${prog.weeksCount} sem. • ${prog.sessionsPerWeek} séances/sem.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$pct%',
                style: AppTypography.metric(
                  color: AppColors.rose,
                  fontSize: 34,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: prog.progressRatio,
              minHeight: 8,
              backgroundColor: AppColors.level2,
              color: AppColors.rose,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                '$doneCount sur $totalCount séances validées',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (prog.notificationsEnabled)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      size: 14,
                      color: AppColors.rose,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Rappel ${prog.trainingTime}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWeeklyScheduleWidgets(
    BuildContext context,
    TrainingProgram prog,
  ) {
    final schedule = prog.buildSchedule();
    final widgets = <Widget>[];

    for (int w = 1; w <= prog.weeksCount; w++) {
      final weekSessions = schedule.where((s) => s.weekNumber == w).toList();
      if (weekSessions.isEmpty) continue;

      final doneInWeek = weekSessions.where((s) => s.isCompleted).length;

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: AppCards.cardDecoration(radius: AppSpacing.cardRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'SEMAINE $w',
                      style: AppTypography.h3(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    '$doneInWeek / ${weekSessions.length} terminées',
                    style: TextStyle(
                      color: doneInWeek == weekSessions.length
                          ? AppColors.green
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...weekSessions.map((item) {
                final dateStr =
                    DateFormat('dd/MM').format(item.scheduledDateTime);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: AppCards.subCardDecoration(
                    radius: AppSpacing.innerRadius,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.innerRadius),
                    onTap: () => _showWorkoutDetailsModal(context, item.workout),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          // Checkbox : coche la session spécifique item.id
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              item.isCompleted
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: item.isCompleted
                                  ? AppColors.green
                                  : AppColors.textMuted,
                              size: 24,
                            ),
                            onPressed: () {
                              widget.appState
                                  .toggleWorkoutCompletionInActiveProgram(item.id);
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.weekdayLabel} $dateStr • ${item.trainingTime}',
                                  style: TextStyle(
                                    color: AppColors.rose,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.workout.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    decoration: item.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                Text(
                                  '${item.workout.formattedDuration} • ${item.workout.steps.length} blocs • SMR max ${item.workout.maxResistance}/24',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  // --- Modal Détails de Séance (au clic sur une séance du programme) ---

  void _showWorkoutDetailsModal(BuildContext context, Workout workout) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.level0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        maxChildSize: 0.94,
        minChildSize: 0.5,
        builder: (context, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    workout.title,
                    style: AppTypography.h1(fontSize: 22),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              workout.description,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            // Badges durée, blocs, résistance
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildModalBadge(Icons.timer_outlined, workout.formattedDuration),
                _buildModalBadge(Icons.view_week_outlined, '${workout.steps.length} blocs'),
                _buildModalBadge(Icons.speed, 'SMR max ${workout.maxResistance}/24'),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'PROFIL DE RÉSISTANCE',
              style: AppTypography.h3(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: AppCards.cardDecoration(radius: 18),
              child: WorkoutResistanceProfileChart(
                steps: workout.steps,
                height: 80,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'DÉTAIL DES INTERVALLES',
              style: AppTypography.h3(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            ...workout.steps.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: AppCards.subCardDecoration(radius: 12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: stepTypeColor(s.type),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${s.durationSeconds}s @ SMR ${s.targetResistance}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rose,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                widget.onSelectWorkoutForLandscape(workout);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Séance "${workout.title}" sélectionnée ! Ramez dès maintenant pour démarrer automatiquement (portrait ou paysage).',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'Démarrer cette séance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.level1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.rose),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- Modal de création / modification simplifié de programme ---

  void _showProgramEditorModal(
    BuildContext context, {
    TrainingProgram? existing,
  }) {
    final user = widget.appState.activeUser;
    WorkoutGoal selectedGoal = existing?.goal ?? user.goal;
    int selectedWeeks = existing?.weeksCount ?? 4;
    int selectedSessionsPerWeek = existing?.sessionsPerWeek ?? 3;
    List<int> selectedDays =
        List<int>.from(existing?.trainingDays ?? const [1, 3, 5]);
    String selectedTime = existing?.trainingTime ?? '18:30';
    bool notificationsEnabled =
        existing?.notificationsEnabled ?? widget.appState.notificationsEnabled;
    bool isSaving = false;

    const allWeekdays = [1, 2, 3, 4, 5, 6, 7];
    const presetTimes = ['07:00', '08:30', '12:30', '18:00', '18:30', '19:30'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.level0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.94,
            minChildSize: 0.6,
            builder: (context, scrollCtrl) => ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(AppSpacing.cardPadding + 4),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        existing == null
                            ? 'CRÉER UN PROGRAMME'
                            : 'MODIFIER LE PROGRAMME',
                        style: AppTypography.h1(fontSize: 22),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. Objectif
                DropdownButtonFormField<WorkoutGoal>(
                  isExpanded: true,
                  initialValue: selectedGoal,
                  decoration: const InputDecoration(
                    labelText: 'Objectif du programme',
                  ),
                  items: WorkoutGoal.values
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text(
                            g.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedGoal = v);
                  },
                ),
                const SizedBox(height: 14),

                // 2. Durée & Rythme
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: selectedWeeks,
                        decoration: const InputDecoration(
                          labelText: 'Durée',
                        ),
                        items: const [2, 4, 6, 8, 12]
                            .map(
                              (w) => DropdownMenuItem(
                                value: w,
                                child: Text('$w semaines'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => selectedWeeks = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: selectedSessionsPerWeek,
                        decoration: const InputDecoration(
                          labelText: 'Séances/sem.',
                        ),
                        items: const [1, 2, 3, 4, 5, 6, 7]
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text('$s / sem.'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setModalState(() => selectedSessionsPerWeek = v);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 3. Jours d'entraînement
                Text(
                  'JOURS D\'ENTRAÎNEMENT',
                  style: AppTypography.h3(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allWeekdays.map((day) {
                    final isSelected = selectedDays.contains(day);
                    return FilterChip(
                      selectedColor: AppColors.rose.withValues(alpha: 0.25),
                      checkmarkColor: AppColors.rose,
                      label: Text(
                        TrainingProgram.weekdayShortName(day),
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.rose
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (val) {
                        setModalState(() {
                          if (val) {
                            selectedDays.add(day);
                          } else if (selectedDays.length > 1) {
                            selectedDays.remove(day);
                          }
                          selectedDays.sort();
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // 4. Heure de rappel
                Text(
                  'HEURE DU RAPPEL',
                  style: AppTypography.h3(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...presetTimes.map(
                      (t) => ChoiceChip(
                        selectedColor: AppColors.rose.withValues(alpha: 0.25),
                        label: Text(
                          t,
                          style: TextStyle(
                            color: selectedTime == t
                                ? AppColors.rose
                                : AppColors.textSecondary,
                            fontWeight: selectedTime == t
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        selected: selectedTime == t,
                        onSelected: (_) =>
                            setModalState(() => selectedTime = t),
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.access_time, size: 16),
                      label: Text('Autre ($selectedTime)'),
                      onPressed: () async {
                        final parts = selectedTime.split(':');
                        final initial = TimeOfDay(
                          hour: int.tryParse(parts[0]) ?? 18,
                          minute: parts.length > 1
                              ? (int.tryParse(parts[1]) ?? 30)
                              : 30,
                        );
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: initial,
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedTime =
                                '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 5. Activation des notifications réelles
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.level1,
                    borderRadius: BorderRadius.circular(AppSpacing.innerRadius),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Rappel de séance',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'Notification sur votre téléphone à $selectedTime les jours programmés',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      value: notificationsEnabled,
                      onChanged: (v) =>
                          setModalState(() => notificationsEnabled = v),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // 6. Validation du programme (utilise UNIQUEMENT les séances de l'app)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rose,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setModalState(() => isSaving = true);

                          final catalog = widget.appState.workouts;
                          final totalSessions =
                              selectedWeeks * selectedSessionsPerWeek;
                          final assignedWorkouts = <Workout>[];

                          // Attribution des séances depuis l'onglet Séances types existant
                          for (int i = 0; i < totalSessions; i++) {
                            final w = catalog[i % catalog.length];
                            assignedWorkouts.add(w);
                          }

                          final newProgram = TrainingProgram(
                            id: existing?.id ??
                                'prog_${DateTime.now().millisecondsSinceEpoch}',
                            title: 'Programme ${selectedGoal.label}',
                            description:
                                'Programme de $selectedWeeks semaines ($selectedSessionsPerWeek séances/semaine).',
                            userId: user.id,
                            goal: selectedGoal,
                            weeksCount: selectedWeeks,
                            sessionsPerWeek: selectedSessionsPerWeek,
                            trainingDays: selectedDays,
                            trainingTime: selectedTime,
                            notificationsEnabled: notificationsEnabled,
                            isAiGenerated: false,
                            workouts: assignedWorkouts,
                            completedWorkoutIds: existing?.completedWorkoutIds ?? const [],
                            createdAt: DateTime.now(),
                          );

                          await widget.appState.saveProgram(newProgram);

                          // Programmer des rappels de notifications réelles si activé
                          if (notificationsEnabled) {
                            try {
                              final schedule = newProgram.buildSchedule();
                              for (int i = 0; i < schedule.length && i < 10; i++) {
                                final s = schedule[i];
                                if (!s.isCompleted &&
                                    s.scheduledDateTime.isAfter(DateTime.now())) {
                                  await NotificationService.instance
                                      .scheduleSessionReminder(
                                    id: 200 + i,
                                    scheduledDate: s.scheduledDateTime,
                                    title: 'Rameur : C\'est l\'heure de votre séance !',
                                    body: 'Séance prévue : "${s.workout.title}". Prêt à pagayer ?',
                                  );
                                }
                              }
                            } catch (_) {}
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    existing == null
                        ? 'Créer le Programme'
                        : 'Enregistrer les modifications',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

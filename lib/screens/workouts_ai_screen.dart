import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/ai_coach_service.dart';
import '../services/app_state_service.dart';
import '../theme/app_theme.dart';
import '../widgets/telemetry_charts.dart';

class WorkoutsAiScreen extends StatefulWidget {
  final AppStateService appState;
  final Workout? selectedWorkoutForLandscape;
  final ValueChanged<Workout> onLaunchWorkout;

  const WorkoutsAiScreen({
    super.key,
    required this.appState,
    this.selectedWorkoutForLandscape,
    required this.onLaunchWorkout,
  });

  @override
  State<WorkoutsAiScreen> createState() => _WorkoutsAiScreenState();
}

class _WorkoutsAiScreenState extends State<WorkoutsAiScreen> {
  int _selectedSubTab = 0; // 0: Séances types, 1: Créer via IA
  bool _isGeneratingAi = false;

  final _aiPromptCtrl = TextEditingController(
    text: 'Fractionné 30/30 haute résistance SMR avec sprint final',
  );
  int _aiDurationMinutes = 20;
  String _aiIntensity = 'intense';

  @override
  void dispose() {
    _aiPromptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: [
                      ButtonSegment(
                        value: 0,
                        icon: const Icon(Icons.list_alt, size: 16),
                        label: Text(
                          'Séances types',
                          style: TextStyle(
                            color: _selectedSubTab == 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: Text(
                          'Création via IA',
                          style: TextStyle(
                            color: _selectedSubTab == 1
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    selected: {_selectedSubTab},
                    onSelectionChanged: (s) =>
                        setState(() => _selectedSubTab = s.first),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.level1,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1.2,
                        ),
                      ),
                    ),
                    onPressed: () => _showCustomIntervalBuilderModal(context),
                    icon: Icon(
                      Icons.add,
                      size: 18,
                      color: AppColors.rose,
                    ),
                    label: const Text(
                      'Créer une séance type manuellement',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _selectedSubTab == 0
                  ? _buildWorkoutsCatalog(context)
                  : _buildAiWorkoutGenerator(context),
            ),
          ],
        );
      },
    );
  }

  void _copyWorkout(Workout wk) async {
    final copy = Workout(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: '${wk.title} (Copie)',
      description: wk.description,
      category: wk.category,
      createdByUserId: widget.appState.activeUser.id,
      isAiGenerated: false,
      steps: wk.steps
          .map((s) => s.copyWith(
                id: 'step_${DateTime.now().microsecondsSinceEpoch}_${s.id}',
              ))
          .toList(),
      createdAt: DateTime.now(),
    );
    await widget.appState.saveWorkout(copy);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Séance copiée : "${copy.title}"'),
        ),
      );
    }
  }

  // --- ONGLET 0 : Liste des séances types déjà créées ---

  Widget _buildWorkoutsCatalog(BuildContext context) {
    final workouts = widget.appState.workouts;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.pageTop,
        AppSpacing.pageHorizontal,
        90,
      ),
      itemCount: workouts.length,
      itemBuilder: (context, index) {
        final wk = workouts[index];
        final isSelected = widget.selectedWorkoutForLandscape?.id == wk.id;

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: AppCards.cardDecoration(
            radius: AppSpacing.cardRadius,
            border: isSelected
                ? Border.all(color: AppColors.rose, width: 1.5)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: wk.isAiGenerated
                        ? AppCards.tagDecoration()
                        : BoxDecoration(
                            color: AppColors.pastelSlateBlue,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          wk.isAiGenerated
                              ? Icons.auto_awesome
                              : Icons.fitness_center,
                          size: 13,
                          color: wk.isAiGenerated
                              ? AppColors.rosePastel
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          wk.isAiGenerated ? 'IA' : 'TYPE',
                          style: TextStyle(
                            color: wk.isAiGenerated
                                ? AppColors.rosePastel
                                : AppColors.primary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      wk.title,
                      style: AppTypography.h2(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  // Bouton Modifier
                  IconButton(
                    tooltip: 'Modifier la séance',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: AppColors.rose,
                    ),
                    onPressed: () => _showCustomIntervalBuilderModal(
                      context,
                      initialWorkout: wk,
                    ),
                  ),
                  // Bouton Copier
                  IconButton(
                    tooltip: 'Dupliquer / Copier la séance',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.copy_rounded,
                      size: 19,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => _copyWorkout(wk),
                  ),
                  // Bouton Supprimer (si personnalisé ou IA)
                  if (wk.id.startsWith('custom_') || wk.id.startsWith('ai_'))
                    IconButton(
                      tooltip: 'Supprimer',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () => widget.appState.deleteWorkout(wk.id),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                wk.description,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              WorkoutResistanceProfileChart(
                steps: wk.steps,
                height: 70,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _BadgeInfo(
                          icon: Icons.timer_outlined,
                          text: wk.formattedDuration,
                          bgColor: AppColors.level2,
                        ),
                        _BadgeInfo(
                          icon: Icons.view_week_outlined,
                          text: '${wk.steps.length} blocs',
                          bgColor: AppColors.level2,
                        ),
                        _BadgeInfo(
                          icon: Icons.speed,
                          text: 'SMR max ${wk.maxResistance}/24',
                          bgColor: AppColors.pastelSand,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isSelected
                          ? AppColors.rose
                          : AppColors.level2,
                      foregroundColor: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () {
                      widget.onLaunchWorkout(wk);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Séance "${wk.title}" prête ! Tournez votre téléphone en mode paysage pour démarrer.',
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      isSelected ? Icons.check : Icons.play_arrow,
                      size: 16,
                    ),
                    label: Text(isSelected ? 'Prête' : 'Choisir'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- ONGLET 1 : Création de séances types via IA (en fonction de l'utilisateur et son objectif) ---

  Widget _buildAiWorkoutGenerator(BuildContext context) {
    final user = widget.appState.activeUser;
    final userSessions = widget.appState.sessions;

    const quickPrompts = [
      'Fractionné 30/30 haute résistance SMR avec sprint final',
      'Pyramide de force progressive SMR 8 → 22 → 8',
      'Tabata brûle-graisses explosif',
      'Endurance fondamentale tempo régulier',
    ];

    return ListView(
      padding: AppSpacing.page,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding + 4),
          decoration: AppCards.cardDecoration(radius: AppSpacing.cardRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: AppCards.tagDecoration(color: AppColors.rose),
                    child: Icon(
                      Icons.auto_awesome,
                      color: AppColors.rosePastel,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CRÉATION DE SÉANCE TYPE VIA IA',
                          style: AppTypography.bebasTitle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Calibrée pour ${user.name} (${user.age} ans, ${user.heightCm} cm, ${user.weightKg.toInt()} kg)',
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
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: AppCards.subCardDecoration(
                  radius: AppSpacing.innerRadius,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      size: 18,
                      color: AppColors.rose,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Objectif du profil : ${user.goal.label}',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _aiPromptCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Précisez votre envie (optionnel)',
                  hintText:
                      'Ex: Séance fractionné pyramidal pour exploser mon record 2000m...',
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: quickPrompts
                    .map(
                      (p) => ActionChip(
                        label: Text(p, style: const TextStyle(fontSize: 11)),
                        onPressed: () => setState(() => _aiPromptCtrl.text = p),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _aiDurationMinutes,
                      decoration: const InputDecoration(
                        labelText: 'Durée',
                      ),
                      items: const [10, 15, 20, 25, 30, 45, 60]
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                '$m min',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _aiDurationMinutes = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _aiIntensity,
                      decoration: const InputDecoration(
                        labelText: 'Intensité SMR',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'douce',
                          child: Text(
                            'Douce (4-10)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'moderee',
                          child: Text(
                            'Modérée (8-15)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'intense',
                          child: Text(
                            'Intense (12-20)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'maximale',
                          child: Text(
                            'Max (16-24)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _aiIntensity = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.isDark ? const Color(0xFF0F172A) : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isGeneratingAi
                      ? null
                      : () async {
                          setState(() => _isGeneratingAi = true);
                          final generated =
                              await AiCoachService.generateCustomWorkout(
                            user: user,
                            userHistory: userSessions,
                            durationMinutes: _aiDurationMinutes,
                            focusPrompt: _aiPromptCtrl.text,
                            intensity: _aiIntensity,
                            geminiApiKey: widget.appState.geminiApiKey,
                          );
                          await widget.appState.saveWorkout(generated);
                          if (!mounted) return;
                          setState(() {
                            _isGeneratingAi = false;
                            _selectedSubTab = 0;
                          });
                        },
                  icon: _isGeneratingAi
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.level0,
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _isGeneratingAi
                        ? 'Génération IA en cours...'
                        : 'Générer la Séance Type via IA',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- CONSTRUCTEUR MANUEL DE SÉANCE TYPE ---

  void _showCustomIntervalBuilderModal(
    BuildContext context, {
    Workout? initialWorkout,
  }) {
    final titleCtrl = TextEditingController(
      text: initialWorkout?.title ?? 'Ma Séance Type',
    );
    final descCtrl = TextEditingController(
      text: initialWorkout?.description ??
          'Séance créée manuellement avec paliers de résistance SMR.',
    );

    final steps = initialWorkout != null
        ? initialWorkout.steps.map((s) => s.copyWith()).toList()
        : <WorkoutStep>[
            const WorkoutStep(
              id: 'b1',
              title: 'Échauffement progressif',
              type: StepType.warmup,
              durationSeconds: 180,
              targetResistance: 6,
              targetSpmMin: 20,
              targetSpmMax: 23,
            ),
            const WorkoutStep(
              id: 'b2',
              title: 'Effort #1',
              type: StepType.work,
              durationSeconds: 60,
              targetResistance: 16,
              targetSpmMin: 27,
              targetSpmMax: 30,
            ),
            const WorkoutStep(
              id: 'b3',
              title: 'Récupération Active #1',
              type: StepType.rest,
              durationSeconds: 45,
              targetResistance: 6,
              targetSpmMin: 18,
              targetSpmMax: 21,
            ),
            const WorkoutStep(
              id: 'b4',
              title: 'Retour au calme',
              type: StepType.cooldown,
              durationSeconds: 120,
              targetResistance: 4,
              targetSpmMin: 18,
              targetSpmMax: 20,
            ),
          ];

    int repeatCount = 4;
    int repeatWorkSec = 45;
    int repeatWorkRes = 16;
    int repeatRestSec = 30;
    int repeatRestRes = 6;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final totalSec =
              steps.fold<int>(0, (s, e) => s + e.durationSeconds);

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.88,
            maxChildSize: 0.95,
            minChildSize: 0.6,
            builder: (context, scrollCtrl) => ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(AppSpacing.cardPadding + 4),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        initialWorkout != null
                            ? 'MODIFIER LA SÉANCE'
                            : 'CRÉER UNE SÉANCE TYPE',
                        style: AppTypography.h1(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la séance type',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description / Notes',
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppCards.cardDecoration(radius: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'APERÇU DU PROFIL SMR (${totalSec ~/ 60} min ${totalSec % 60}s • ${steps.length} blocs)',
                        style: AppTypography.bebasSection(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      WorkoutResistanceProfileChart(
                        steps: steps,
                        height: 75,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppCards.cardDecoration(radius: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚡ AJOUT RAPIDE DE SÉRIE FRACTIONNÉE (N×)',
                        style: AppTypography.bebasSection(
                          color: AppColors.orange,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          DropdownButton<int>(
                            value: repeatCount,
                            items: [2, 3, 4, 5, 6, 8, 10]
                                .map(
                                  (n) => DropdownMenuItem(
                                    value: n,
                                    child: Text('$n × Répétitions'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setModalState(() => repeatCount = v);
                              }
                            },
                          ),
                          DropdownButton<int>(
                            value: repeatWorkSec,
                            items: [20, 30, 45, 60, 90, 120]
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text('Effort ${s}s'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setModalState(() => repeatWorkSec = v);
                              }
                            },
                          ),
                          DropdownButton<int>(
                            value: repeatWorkRes,
                            items: List.generate(24, (i) => i + 1)
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text('@ SMR $r'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setModalState(() => repeatWorkRes = v);
                              }
                            },
                          ),
                          DropdownButton<int>(
                            value: repeatRestSec,
                            items: [15, 20, 30, 45, 60, 90]
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text('Récup ${s}s'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setModalState(() => repeatRestSec = v);
                              }
                            },
                          ),
                          DropdownButton<int>(
                            value: repeatRestRes,
                            items: List.generate(15, (i) => i + 1)
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text('@ SMR $r'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setModalState(() => repeatRestRes = v);
                              }
                            },
                          ),
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.level2,
                              foregroundColor: AppColors.textPrimary,
                            ),
                            onPressed: () {
                              setModalState(() {
                                final insertIdx = steps.length > 1
                                    ? steps.length - 1
                                    : steps.length;
                                final newBlocks = <WorkoutStep>[];
                                for (int i = 1; i <= repeatCount; i++) {
                                  newBlocks.add(
                                    WorkoutStep(
                                      id: 'rep_w_${DateTime.now().microsecondsSinceEpoch}_$i',
                                      title:
                                          'Sprint Fractionné #$i/$repeatCount',
                                      type: StepType.work,
                                      durationSeconds: repeatWorkSec,
                                      targetResistance: repeatWorkRes,
                                      targetSpmMin: 28,
                                      targetSpmMax: 32,
                                    ),
                                  );
                                  newBlocks.add(
                                    WorkoutStep(
                                      id: 'rep_r_${DateTime.now().microsecondsSinceEpoch}_$i',
                                      title: 'Récupération #$i/$repeatCount',
                                      type: StepType.rest,
                                      durationSeconds: repeatRestSec,
                                      targetResistance: repeatRestRes,
                                      targetSpmMin: 18,
                                      targetSpmMax: 21,
                                    ),
                                  );
                                }
                                steps.insertAll(insertIdx, newBlocks);
                              });
                            },
                            icon: const Icon(Icons.repeat, size: 18),
                            label: Text('Injecter les $repeatCount cycles'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      'BLOCS DE LA SÉANCE',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setModalState(() {
                          steps.add(
                            WorkoutStep(
                              id: 'step_${DateTime.now().microsecondsSinceEpoch}',
                              title: 'Intervalle #${steps.length + 1}',
                              type: StepType.work,
                              durationSeconds: 60,
                              targetResistance: 12,
                              targetSpmMin: 24,
                              targetSpmMax: 28,
                            ),
                          );
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Ajouter un bloc'),
                    ),
                  ],
                ),
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
                            items: StepType.values
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(
                                      t.label,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: stepTypeColor(t),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
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
                          width: 76,
                          child: TextFormField(
                            initialValue: '${s.durationSeconds}',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Durée',
                              labelStyle: TextStyle(fontSize: 11),
                              suffixText: 's',
                              suffixStyle: TextStyle(fontSize: 11),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 7,
                              ),
                            ),
                            onChanged: (v) {
                              final parsed = int.tryParse(v);
                              if (parsed != null && parsed > 0) {
                                setModalState(() {
                                  steps[idx] = s.copyWith(
                                    durationSeconds: parsed.clamp(1, 7200),
                                  );
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 64,
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
                              labelText: 'SMR',
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
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rose,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final workout = Workout(
                      id: initialWorkout?.id ??
                          'custom_${DateTime.now().millisecondsSinceEpoch}',
                      title: titleCtrl.text.trim().isEmpty
                          ? (initialWorkout?.title ?? 'Séance Personnalisée')
                          : titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      category: initialWorkout?.category ?? 'custom',
                      createdByUserId: widget.appState.activeUser.id,
                      isAiGenerated: initialWorkout?.isAiGenerated ?? false,
                      steps: steps,
                      createdAt: initialWorkout?.createdAt ?? DateTime.now(),
                    );
                    await widget.appState.saveWorkout(workout);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            initialWorkout != null
                                ? 'Séance "${workout.title}" mise à jour !'
                                : 'Séance "${workout.title}" enregistrée !',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: Text(
                    initialWorkout != null
                        ? 'Enregistrer les modifications'
                        : 'Enregistrer cette Séance Type',
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
}

class _BadgeInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bgColor;

  const _BadgeInfo({
    required this.icon,
    required this.text,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

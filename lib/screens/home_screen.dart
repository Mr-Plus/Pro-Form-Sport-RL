import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/app_state_service.dart';
import '../services/proform_ble_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final AppStateService appState;
  final ProFormBleService bleService;
  final Workout? selectedWorkoutForLandscape;
  final ValueChanged<Workout> onSelectWorkoutForLandscape;
  final VoidCallback onGoToProgramTab;
  final VoidCallback onOpenSettings;

  const HomeScreen({
    super.key,
    required this.appState,
    required this.bleService,
    required this.selectedWorkoutForLandscape,
    required this.onSelectWorkoutForLandscape,
    required this.onGoToProgramTab,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, bleService]),
      builder: (context, _) {
        final prog = appState.activeProgram;
        final isRigorous = appState.isUserRigorous;
        final nextSession = prog?.nextScheduledSession;

        final totalMeters = appState.sessions.fold<double>(
          0.0,
          (sum, s) => sum + s.distanceMeters,
        );
        final totalKcal = appState.sessions.fold<double>(
          0.0,
          (sum, s) => sum + s.caloriesKcal,
        );
        final totalSeconds = appState.sessions.fold<int>(
          0,
          (sum, s) => sum + s.durationSeconds,
        );
        final totalHours = totalSeconds ~/ 3600;
        final totalMinutes = (totalSeconds % 3600) ~/ 60;
        final timeStr = totalHours > 0
            ? '${totalHours}h ${totalMinutes}m'
            : '${totalMinutes}m';

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.hasBoundedHeight
                      ? constraints.maxHeight
                      : 0.0,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: AppSpacing.page,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 6),

                        // 1. En-tête héroïque dynamique
                        _buildHeroHeadline(isRigorous, nextSession),

                        const SizedBox(height: 22),

                        // 2. Ligne 50% / 50% : Carte Programme (anneau néon) & Carte Prochaine session
                        _buildHalfCardsRow(prog, nextSession),

                        const SizedBox(height: 22),

                        // 3. Carte Bilan Global : 3 colonnes Distance / Calories / Temps
                        _buildStatsCard(
                          totalMeters: totalMeters,
                          totalKcal: totalKcal,
                          timeStr: timeStr,
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Bannière héroïque athlétique avec contexte utilisateur et accès rapide
  Widget _buildHeroHeadline(
    bool isRigorous,
    ScheduledProgramSession? nextSession,
  ) {
    final user = appState.activeUser;
    final userName = user.name.isNotEmpty ? user.name : 'Alex';
    final hour = DateTime.now().hour;
    final greeting = (hour >= 18 || hour < 5) ? 'Bonsoir' : 'Bonjour';
    final isBleConnected = bleService.isHardwareConnected;
    final sessionCount = appState.sessions.length;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.rose.withValues(alpha: 0.24),
            AppColors.level1,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.rose.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.rose.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -12,
              top: -8,
              child: Icon(
                Icons.rowing_rounded,
                size: 112,
                color: AppColors.rosePastel.withValues(alpha: 0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$greeting, $userName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isBleConnected
                                  ? AppColors.green
                                  : AppColors.rose)
                              .withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (isBleConnected
                                    ? AppColors.green
                                    : AppColors.rose)
                                .withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isBleConnected
                                  ? Icons.bluetooth_connected_rounded
                                  : Icons.bolt_rounded,
                              size: 13,
                              color: isBleConnected
                                  ? AppColors.green
                                  : AppColors.rosePastel,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isBleConnected
                                  ? 'Rameur connecté'
                                  : '$sessionCount séance${sessionCount > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isBleConnected
                                    ? AppColors.green
                                    : AppColors.rosePastel,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'DÉPASSE TES LIMITES',
                    style: AppTypography.h1(
                      fontSize: 30,
                      color: Colors.white,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${user.goal.label} • Niveau ${user.level.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.rosePastel,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (nextSession != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'À suivre : ${nextSession.workout.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          style: AppButtons.compact(),
                          onPressed: () =>
                              onSelectWorkoutForLandscape(nextSession.workout),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Démarrer'),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Icon(
                          Icons.screen_rotation_rounded,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tournez le téléphone en paysage pour ramer',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ligne 50% / 50% : Graph du programme & Date de la prochaine session
  Widget _buildHalfCardsRow(
    TrainingProgram? prog,
    ScheduledProgramSession? nextSession,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Carte 1 : Programme
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PROGRAMME',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.h1(fontSize: 22),
              ),
              const SizedBox(height: AppSpacing.headerGap),
              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onGoToProgramTab,
                child: Container(
                  height: 175,
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.level1,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 90,
                      height: 90,
                      child: Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: prog != null ? prog.progressRatio : 0.0,
                            strokeWidth: 8.5,
                            backgroundColor: const Color(0xFF223049),
                            color: AppColors.rose,
                            strokeCap: StrokeCap.round,
                          ),
                          Center(
                            child: Text(
                              '${prog?.progressPercent ?? 0}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
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
        const SizedBox(width: 16),

        // Carte 2 : Prochaine session
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PROCHAINE SESSION',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.h1(fontSize: 22),
              ),
              const SizedBox(height: AppSpacing.headerGap),
              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  if (nextSession != null) {
                    onSelectWorkoutForLandscape(nextSession.workout);
                  } else {
                    onGoToProgramTab();
                  }
                },
                child: Container(
                  height: 175,
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.level1,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (nextSession != null) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              nextSession.weekdayLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nextSession.trainingTime,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.rose.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.rose.withValues(alpha: 0.45),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              nextSession.workout.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.rosePastel,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Aucune séance prévue',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: AppButtons.compact(),
                            onPressed: onGoToProgramTab,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Ajouter'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Carte Bilan Global : 3 colonnes spacieuses (Distance, Calories, Temps)
  Widget _buildStatsCard({
    required double totalMeters,
    required double totalKcal,
    required String timeStr,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BILAN GLOBAL',
          style: AppTypography.h1(fontSize: 22),
        ),
        const SizedBox(height: AppSpacing.headerGap),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.level1,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Colonne 1 : Distance
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(totalMeters / 1000).toStringAsFixed(1)} km',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Distance',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 38,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              // Colonne 2 : Calories
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${NumberFormat.decimalPattern().format(totalKcal.round())} kcal',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Calories',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 38,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              // Colonne 3 : Temps
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Temps',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

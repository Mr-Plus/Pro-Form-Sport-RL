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

                        // 1. En-tête : Salutation "Bonjour, Alex" & "Dépassez vos limites" (rose corail)
                        _buildHeroHeadline(isRigorous),

                        const SizedBox(height: 26),

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

  /// Titre héroïque : "Bonjour, [Prénom]" puis "Dépasse tes limites" en rose corail
  Widget _buildHeroHeadline(bool isRigorous) {
    final userName = appState.activeUser.name.isNotEmpty
        ? appState.activeUser.name
        : 'Alex';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bonjour, $userName',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Dépasse\ntes limites',
          style: TextStyle(
            color: AppColors.rosePastel,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }

  /// Ligne 50% / 50% : Graph du programme & Date de la prochaine session
  Widget _buildHalfCardsRow(
    TrainingProgram? prog,
    ScheduledProgramSession? nextSession,
  ) {
    return Row(
      children: [
        // Carte 1 : Programme
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onGoToProgramTab,
            child: Container(
              height: 200,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                children: [
                  Text(
                    'Programme',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: SizedBox(
                      width: 86,
                      height: 86,
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
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Carte 2 : Prochaine session
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              if (nextSession != null) {
                onSelectWorkoutForLandscape(nextSession.workout);
              } else {
                onGoToProgramTab();
              }
            },
            child: Container(
              height: 200,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  Text(
                    'Prochaine\nsession',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nextSession != null
                            ? nextSession.weekdayLabel
                            : 'Samedi',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.15,
                        ),
                      ),
                      Text(
                        nextSession != null
                            ? nextSession.trainingTime
                            : '10:00',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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
                        vertical: 4,
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
                        nextSession?.workout.title ?? 'Accent',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.rosePastel,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bilan Global',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
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
        ],
      ),
    );
  }
}

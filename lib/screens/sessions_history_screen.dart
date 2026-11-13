import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/app_state_service.dart';
import '../theme/app_theme.dart';
import '../widgets/telemetry_charts.dart';

class SessionsHistoryScreen extends StatelessWidget {
  final AppStateService appState;

  const SessionsHistoryScreen({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final sessions = appState.sessions;

        if (sessions.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.pageTop,
              AppSpacing.pageHorizontal,
              95,
            ),
            children: [
              Text(
                'HISTORIQUE',
                style: AppTypography.h1(fontSize: 22),
              ),
              const SizedBox(height: AppSpacing.headerGap),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: AppCards.cardDecoration(radius: AppSpacing.cardRadius),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      size: 48,
                      color: AppColors.rose,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Aucune session enregistrée',
                      style: AppTypography.bebasCardTitle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tournez votre téléphone en mode paysage pour démarrer votre première session sur le rameur !',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.pageTop,
            AppSpacing.pageHorizontal,
            95,
          ),
          itemCount: sessions.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.headerGap),
                child: Text(
                  'HISTORIQUE',
                  style: AppTypography.h1(fontSize: 22),
                ),
              );
            }
            final s = sessions[index - 1];
            final dateStr = DateFormat('dd/MM/yyyy • HH:mm').format(s.startedAt);

            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
              decoration: AppCards.cardDecoration(radius: AppSpacing.cardRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                onTap: () => _showSessionDetailsSheet(context, s),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: AppCards.tagDecoration(color: AppColors.rose),
                        child: Icon(
                          Icons.rowing,
                          color: AppColors.rosePastel,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (s.workoutTitle.isNotEmpty) ...[
                              Text(
                                s.workoutTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bebasCardTitle(
                                  color: AppColors.textPrimary,
                                  fontSize: 19,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ] else ...[
                              Text(
                                dateStr,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            // Distance & Durée
                            Row(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.straighten,
                                      size: 15,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${s.distanceMeters.round()} m',
                                      style: AppTypography.bebasMetric(
                                        color: AppColors.textPrimary,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 18),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      size: 15,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      s.formattedDuration,
                                      style: AppTypography.bebasMetric(
                                        color: AppColors.textPrimary,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSessionDetailsSheet(BuildContext context, RowingSession s) {
    final dateStr = DateFormat('EEEE dd MMMM yyyy à HH:mm', 'fr_FR').format(s.startedAt);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(AppSpacing.cardPadding + 4),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DÉTAIL DE LA SESSION',
                        style: AppTypography.bebasTitle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.workoutTitle,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  icon: Icon(Icons.delete_outline, color: AppColors.red),
                  onPressed: () {
                    appState.deleteSession(s.id);
                    Navigator.pop(ctx);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Affichage de toutes les infos ligne par ligne
            Container(
              decoration: AppCards.cardDecoration(radius: AppSpacing.cardRadius),
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Date & Heure',
                    value: dateStr,
                    isFirst: true,
                  ),
                  _DetailRow(
                    label: 'Durée de session',
                    value: s.formattedDuration,
                  ),
                  _DetailRow(
                    label: 'Distance parcourue',
                    value: '${s.distanceMeters.round()} m',
                  ),
                  _DetailRow(
                    label: 'Allure moyenne (/500m)',
                    value: s.formattedSplit,
                  ),
                  _DetailRow(
                    label: 'Puissance moyenne',
                    value: '${s.avgWatts.round()} W',
                  ),
                  _DetailRow(
                    label: 'Puissance maximale',
                    value: '${s.maxWatts} W',
                  ),
                  _DetailRow(
                    label: 'Cadence moyenne',
                    value: '${s.avgCadenceSpm.round()} SPM',
                  ),
                  _DetailRow(
                    label: 'Résistance moyenne',
                    value: 'SMR ${s.avgResistance.toStringAsFixed(1)} / 24',
                  ),
                  _DetailRow(
                    label: 'Nombre de coups de rame',
                    value: '${s.strokesCount}',
                  ),
                  _DetailRow(
                    label: 'Calories brûlées',
                    value: '${s.caloriesKcal.round()} kcal',
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Graph résumé
            Text(
              'GRAPHIQUE RÉSUMÉ DE LA SESSION (WATTS & SMR)',
              style: AppTypography.bebasSection(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            SessionTelemetryLineChart(
              samples: s.samples,
              height: 150,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isFirst;
  final bool isLast;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: AppColors.level2,
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }
}

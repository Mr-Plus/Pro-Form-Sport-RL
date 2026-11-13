import 'dart:math';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

Color stepTypeColor(StepType type) {
  switch (type) {
    case StepType.warmup:
      return AppColors.primary;
    case StepType.work:
      return AppColors.orange;
    case StepType.rest:
      return AppColors.green;
    case StepType.cooldown:
      return AppColors.purple;
  }
}

/// Graphique du profil d'entraînement (blocs de fractionné, durée & résistance SMR 1..24)
class WorkoutResistanceProfileChart extends StatelessWidget {
  final List<WorkoutStep> steps;
  final int? activeStepIndex;
  final double? overallProgressRatio;
  final double height;

  const WorkoutResistanceProfileChart({
    super.key,
    required this.steps,
    this.activeStepIndex,
    this.overallProgressRatio,
    this.height = 96,
  });

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return SizedBox(height: height);
    }
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.level2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _WorkoutProfilePainter(
          steps: steps,
          activeStepIndex: activeStepIndex,
          overallProgressRatio: overallProgressRatio,
        ),
      ),
    );
  }
}

class _WorkoutProfilePainter extends CustomPainter {
  final List<WorkoutStep> steps;
  final int? activeStepIndex;
  final double? overallProgressRatio;

  _WorkoutProfilePainter({
    required this.steps,
    this.activeStepIndex,
    this.overallProgressRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalSec = steps.fold<int>(0, (s, e) => s + max(1, e.durationSeconds));
    if (totalSec <= 0) return;

    // Lignes horizontales de repère SMR (8, 16, 24) en gris doux
    final gridPaint = Paint()
      ..color = AppColors.level3
      ..strokeWidth = 1;
    for (final level in [8, 16, 24]) {
      final y = size.height - (level / 24.0) * (size.height - 10);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    double currentX = 0.0;
    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final stepWidth = (max(1, step.durationSeconds) / totalSec) * size.width;
      final barHeight =
          (step.targetResistance.clamp(1, 24) / 24.0) * (size.height - 12) + 6;
      final isCurrent = activeStepIndex == i;
      final baseColor = stepTypeColor(step.type);

      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          currentX + 1,
          size.height - barHeight,
          max(2.0, stepWidth - 2),
          barHeight,
        ),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );

      final fillPaint = Paint()
        ..color = baseColor.withValues(alpha: isCurrent ? 0.95 : 0.55);

      canvas.drawRRect(rect, fillPaint);

      currentX += stepWidth;
    }

    // Curseur de progression globale
    if (overallProgressRatio != null) {
      final cursorX = (overallProgressRatio!.clamp(0.0, 1.0)) * size.width;
      final cursorPaint = Paint()
        ..color = AppColors.textPrimary
        ..strokeWidth = 2.0;
      canvas.drawLine(
        Offset(cursorX, 0),
        Offset(cursorX, size.height),
        cursorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WorkoutProfilePainter oldDelegate) =>
      oldDelegate.steps != steps ||
      oldDelegate.activeStepIndex != activeStepIndex ||
      oldDelegate.overallProgressRatio != overallProgressRatio;
}

/// Courbe télémétrique Puissance (Watts) & Résistance SMR (1..24)
class SessionTelemetryLineChart extends StatelessWidget {
  final List<SessionSample> samples;
  final double height;

  const SessionTelemetryLineChart({
    super.key,
    required this.samples,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    if (samples.length < 2) {
      return Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.level2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Les courbes de Puissance (W) et Résistance (SMR) s\'afficheront dès les premiers coups de rame.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.level2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _TelemetryCurvePainter(samples: samples),
      ),
    );
  }
}

class _TelemetryCurvePainter extends CustomPainter {
  final List<SessionSample> samples;

  _TelemetryCurvePainter({required this.samples});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;

    final gridPaint = Paint()
      ..color = AppColors.level3
      ..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final maxWatts =
        max(250, samples.map((s) => s.watts).reduce(max)).toDouble();

    final wattsPath = Path();
    final wattsFillPath = Path();
    final resPath = Path();

    for (int i = 0; i < samples.length; i++) {
      final x = (i / (samples.length - 1)) * size.width;
      final wY = size.height -
          ((samples[i].watts / maxWatts).clamp(0.0, 1.0) * (size.height - 14)) -
          4;
      final rY = size.height -
          ((samples[i].resistance / 24.0).clamp(0.0, 1.0) *
              (size.height - 14)) -
          4;

      if (i == 0) {
        wattsPath.moveTo(x, wY);
        wattsFillPath.moveTo(x, size.height);
        wattsFillPath.lineTo(x, wY);
        resPath.moveTo(x, rY);
      } else {
        wattsPath.lineTo(x, wY);
        wattsFillPath.lineTo(x, wY);
        resPath.lineTo(x, rY);
      }
    }

    wattsFillPath.lineTo(size.width, size.height);
    wattsFillPath.close();

    final fillPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12);
    canvas.drawPath(wattsFillPath, fillPaint);

    // Courbe Résistance SMR (Orange)
    final resPaint = Paint()
      ..color = AppColors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(resPath, resPaint);

    // Courbe Puissance Watts (Bleu)
    final wattsPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;
    canvas.drawPath(wattsPath, wattsPaint);
  }

  @override
  bool shouldRepaint(covariant _TelemetryCurvePainter oldDelegate) => true;
}

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/app_state_service.dart';
import '../theme/app_theme.dart';

class UserProfileScreen extends StatefulWidget {
  final AppStateService appState;
  final bool embeddedInTab;

  const UserProfileScreen({
    super.key,
    required this.appState,
    this.embeddedInTab = false,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late TextEditingController _pseudoCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  late FitnessLevel _selectedLevel;
  late WorkoutGoal _selectedGoal;
  String _selectedEmoji = '🚣';

  @override
  void initState() {
    super.initState();
    final user = widget.appState.activeUser;
    _pseudoCtrl = TextEditingController(text: user.name);
    _ageCtrl = TextEditingController(text: '${user.age}');
    _heightCtrl = TextEditingController(text: '${user.heightCm}');
    _weightCtrl = TextEditingController(text: user.weightKg.toInt().toString());
    _selectedLevel = user.level;
    _selectedGoal = user.goal;
    _selectedEmoji = user.avatarEmoji;
  }

  @override
  void dispose() {
    _pseudoCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final name = _pseudoCtrl.text.trim();
    if (name.isEmpty) return;
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 35;
    final height = int.tryParse(_heightCtrl.text.trim()) ?? 178;
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 75.0;

    final updated = widget.appState.activeUser.copyWith(
      name: name,
      avatarEmoji: _selectedEmoji,
      age: age,
      heightCm: height,
      weightKg: weight,
      level: _selectedLevel,
      goal: _selectedGoal,
    );
    widget.appState.saveUserProfile(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profil enregistré avec succès !'),
      ),
    );
  }

  IconData _getGoalIcon(WorkoutGoal goal) {
    switch (goal) {
      case WorkoutGoal.endurance:
        return Icons.favorite_border;
      case WorkoutGoal.hiitWeightLoss:
        return Icons.local_fire_department_outlined;
      case WorkoutGoal.powerStrength:
        return Icons.fitness_center;
      case WorkoutGoal.recovery:
        return Icons.spa_outlined;
    }
  }

  void _showAllGoalsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.level0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          builder: (_, scrollCtrl) {
            return ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.level3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'GUIDE DES 4 OBJECTIFS',
                  style: AppTypography.bebasTitle(
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Valeurs calibrées pour votre niveau (${_selectedLevel.label}). Vous pouvez ajuster votre niveau à tout moment.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.pastelSlateBlue,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.health_and_safety_outlined,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Comprendre Cadence (SPM) & Résistance',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• SPM = coups de rame par minute (votre rythme).\n'
                        '• Résistance (1 à 24) = la dureté du tirage.\n'
                        '• Règle santé : ne combinez jamais résistance maximale et cadence rapide. Plus c\'est lourd, plus on rame lentement.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ...WorkoutGoal.values.map((g) {
                  final isSelected = g == _selectedGoal;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() => _selectedGoal = g);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.pastelSlateBlue
                              : AppColors.level1,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.level2,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.level0,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getGoalIcon(g),
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        g.label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        g.subtitle,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              g.description,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textPrimary,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _buildGoalBadge(
                                  icon: Icons.speed,
                                  label: 'Cadence',
                                  value: g.cadenceForLevel(_selectedLevel),
                                  bgColor: AppColors.pastelSage,
                                  textColor: AppColors.green,
                                ),
                                _buildGoalBadge(
                                  icon: Icons.tune,
                                  label: 'Résistance',
                                  value: g.resistanceForLevel(_selectedLevel),
                                  bgColor: AppColors.pastelSand,
                                  textColor: AppColors.orange,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.tips_and_updates_outlined,
                                    size: 13, color: AppColors.amber),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    g.beginnerTip,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
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
          },
        );
      },
    );
  }

  Widget _buildGoalBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text.rich(
              TextSpan(
                text: '$label : ',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoberTarget({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.level0,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, {IconData? icon, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.isDark = Theme.of(context).brightness == Brightness.dark;
    final content = ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.pageTop,
        AppSpacing.pageHorizontal,
        widget.embeddedInTab ? 95 : AppSpacing.pageBottom,
      ),
      children: [
          // Section 1 : Informations Personnelles
          Text(
            'INFORMATIONS PERSONNELLES',
            style: AppTypography.h1(fontSize: 22),
          ),
          const SizedBox(height: AppSpacing.headerGap),
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: AppCards.cardDecoration(radius: AppSpacing.cardRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel('Pseudo'),
                TextField(
                  controller: _pseudoCtrl,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Votre prénom ou pseudo',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                  ),
                ),
                const SizedBox(height: 16),

                // Âge, Taille & Poids sur une ligne sobre
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Âge'),
                          TextField(
                            controller: _ageCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
                            decoration: InputDecoration(
                              hintText: '34',
                              hintStyle: TextStyle(color: AppColors.textMuted),
                              suffixText: 'ans',
                              suffixStyle: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Taille'),
                          TextField(
                            controller: _heightCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
                            decoration: InputDecoration(
                              hintText: '180',
                              hintStyle: TextStyle(color: AppColors.textMuted),
                              suffixText: 'cm',
                              suffixStyle: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Poids'),
                          TextField(
                            controller: _weightCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
                            decoration: InputDecoration(
                              hintText: '78',
                              hintStyle: TextStyle(color: AppColors.textMuted),
                              suffixText: 'kg',
                              suffixStyle: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),

          // Section 2 : Objectif Sportif
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'OBJECTIF SPORTIF',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h1(fontSize: 22),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showAllGoalsDialog(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.help_outline,
                          size: 15, color: AppColors.rosePastel),
                      const SizedBox(width: 5),
                      Text(
                        'Guide des objectifs',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.rosePastel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.headerGap),
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: AppCards.cardDecoration(radius: AppSpacing.cardRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel('Niveau'),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.level0,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: FitnessLevel.values.map((lvl) {
                      final selected = lvl == _selectedLevel;
                      return Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => setState(() => _selectedLevel = lvl),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.rose
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              lvl.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                _buildFieldLabel('Objectif'),
                DropdownButtonFormField<WorkoutGoal>(
                  isExpanded: true,
                  initialValue: _selectedGoal,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  ),
                  items: WorkoutGoal.values
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text(
                            g.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedGoal = v);
                  },
                ),
                const SizedBox(height: 16),

                Text(
                  _selectedGoal.description,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildSoberTarget(
                        label: 'Cadence cible',
                        value: _selectedGoal.cadenceForLevel(_selectedLevel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSoberTarget(
                        label: 'Résistance cible',
                        value: _selectedGoal.resistanceForLevel(_selectedLevel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Bouton Enregistrer
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: AppButtons.primary(),
              onPressed: _saveProfile,
              icon: const Icon(Icons.check, size: 19),
              label: const Text('Enregistrer les modifications'),
            ),
          ),
        ],
      );
    if (widget.embeddedInTab) return content;
    return Scaffold(
      backgroundColor: AppColors.level0,
      appBar: AppBar(
        title: Text(
          'Profil Utilisateur',
          style: AppTypography.bebasTitle(fontSize: 24),
        ),
      ),
      body: content,
    );
  }
}

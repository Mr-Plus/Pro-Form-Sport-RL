import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_state_service.dart';
import '../services/notification_service.dart';
import '../services/proform_ble_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  final AppStateService appState;
  final ProFormBleService bleService;

  const SettingsScreen({
    super.key,
    required this.appState,
    required this.bleService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, bleService]),
      builder: (context, _) {
        AppColors.isDark = true;
        final isConnected = bleService.isHardwareConnected;
        final isConnecting = bleService.latestTelemetry.isConnecting;
        final tel = bleService.latestTelemetry;

        return Scaffold(
          backgroundColor: AppColors.level0,
          appBar: AppBar(
            title: Text(
              'Paramètres',
              style: AppTypography.h1(fontSize: 24),
            ),
          ),
          body: ListView(
            padding: AppSpacing.page,
            children: [
              // 1. CONNEXION
              _buildRowerSection(context, isConnected, isConnecting, tel),
              const SizedBox(height: AppSpacing.sectionGap),

              // 2. NOTIFICATIONS
              _buildNotificationsSection(context),
              const SizedBox(height: AppSpacing.sectionGap),

              // 3. DIAGNOSTIC & LOGS BLUETOOTH
              _buildBleDiagnosticSection(context),
              const SizedBox(height: AppSpacing.sectionGap),

              // 4. VERSION DE L'APP
              _buildAppVersionSection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRowerSection(
    BuildContext context,
    bool isConnected,
    bool isConnecting,
    dynamic tel,
  ) {
    final statusColor = isConnected
        ? AppColors.green
        : isConnecting
            ? AppColors.amber
            : AppColors.textSecondary;
    final badgeBg = isConnected
        ? AppColors.pastelSage
        : isConnecting
            ? AppColors.pastelSand
            : AppColors.level2;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: AppCards.cardDecoration(radius: AppSpacing.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bluetooth, color: AppColors.rose, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CONNEXION',
                  style: AppTypography.h3(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // État Connexion Bluetooth Rameur
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppCards.subCardDecoration(radius: AppSpacing.innerRadius),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected ? 'Rameur Connecté' : 'Rameur Déconnecté',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isConnected
                            ? '${tel.deviceName} (${tel.deviceId})'
                            : 'Pro-Form Sport RL (I_RW)',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConnected)
                  TextButton(
                    onPressed: () => bleService.disconnectHardware(),
                    child: Text(
                      'Déconnecter',
                      style: TextStyle(color: AppColors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Scan de connexion
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: isConnected ? AppColors.level2 : AppColors.rose,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: isConnecting
                  ? null
                  : () => bleService.scanAndConnectHardware(),
              icon: Icon(
                isConnected ? Icons.refresh : Icons.bluetooth_searching,
                size: 18,
              ),
              label: Text(
                isConnecting
                    ? 'Scan & Connexion en cours...'
                    : isConnected
                        ? 'Relancer le scan de connexion'
                        : 'Lancer le scan de connexion',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Liste des appareils trouvés lors du scan
          if (!isConnected && bleService.discoveredDevices.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Appareils détectés :',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ...bleService.discoveredDevices.take(4).map((r) {
              final name = r.device.platformName.isNotEmpty
                  ? r.device.platformName
                  : (r.advertisementData.advName.isNotEmpty
                      ? r.advertisementData.advName
                      : 'BLE (${r.device.remoteId.str})');
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: AppCards.subCardDecoration(radius: 12),
                child: Row(
                  children: [
                    const Icon(Icons.bluetooth, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => bleService.connectToDevice(r.device),
                      child: const Text('Connecter', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: AppCards.cardDecoration(radius: AppSpacing.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: AppColors.rose, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'NOTIFICATIONS',
                  style: AppTypography.h3(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
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
                'Notifications locales programmées pour vos séances et programmes',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              value: appState.notificationsEnabled,
              onChanged: (val) async {
                await appState.setNotificationsEnabled(val);
                if (val) {
                  await NotificationService.instance.initialize();
                }
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.rose.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: Icon(Icons.send_rounded, size: 16, color: AppColors.rose),
              label: Text(
                'Tester une notification immédiate',
                style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                await NotificationService.instance.sendInstantNotification(
                  title: 'Rameur 🚣‍♂️ Rappel de séance',
                  body: 'C\'est l\'heure de ramer ! Prêt pour battre votre record ?',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notification test envoyée avec succès !'),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBleDiagnosticSection(BuildContext context) {
    final logs = bleService.protocolLogs;
    final rxCount = bleService.latestTelemetry.rxPacketsCount;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: AppCards.cardDecoration(radius: AppSpacing.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terminal_rounded, color: AppColors.rose, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'DIAGNOSTIC & LOGS BLUETOOTH',
                  style: AppTypography.h3(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.level2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$rxCount paquets reçus',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Enregistrement brut des trames échangées avec le rameur. Utile pour identifier précisément l\'encodage de la durée, des coups de rame et des calories.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),

          // Zone d'affichage des logs
          Container(
            height: 160,
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF090D14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      'Aucun log disponible pour l\'instant.\nConnectez le rameur et donnez quelques coups de rame pour capturer les trames.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (ctx, idx) => Text(
                      logs[idx],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10.5,
                        color: Color(0xFF94A3B8),
                        height: 1.35,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),

          // Boutons Copier et Vider
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rose,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    final dump = bleService.getFormattedLogsForExport();
                    await Clipboard.setData(ClipboardData(text: dump));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.rose,
                          content: const Text(
                            'Logs BLE copiés dans le presse-papier !',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text(
                    'Copier les logs BLE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onPressed: () => bleService.clearLogs(),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Effacer'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppVersionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          'Version de l\'application ${AppStateService.appVersion}',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

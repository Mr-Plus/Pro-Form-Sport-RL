import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'models/models.dart';
import 'screens/home_screen.dart';
import 'screens/landscape_session_screen.dart';
import 'screens/program_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sessions_history_screen.dart';
import 'screens/user_profile_screen.dart';
import 'services/app_state_service.dart';
import 'services/live_session_service.dart';
import 'services/notification_service.dart';
import 'services/proform_ble_service.dart';
import 'services/voice_coach_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  try {
    await LiquidGlassWidgets.initialize();
  } catch (e) {
    debugPrint('LiquidGlassWidgets init: $e');
  }
  final appState = AppStateService();
  final bleService = ProFormBleService();
  final voiceCoach = VoiceCoachService();

  runApp(
    LiquidGlassWidgets.wrap(
      child: ProFormRowerApp(
        appState: appState,
        bleService: bleService,
        voiceCoach: voiceCoach,
      ),
    ),
  );

  await appState.init();
  await voiceCoach.init();
  await NotificationService.instance.initialize();
}

class ProFormRowerApp extends StatelessWidget {
  final AppStateService appState;
  final ProFormBleService bleService;
  final VoiceCoachService? voiceCoach;

  const ProFormRowerApp({
    super.key,
    required this.appState,
    required this.bleService,
    this.voiceCoach,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        AppColors.isDark = true;

        return MaterialApp(
          title: 'Rameur',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          builder: (context, child) {
            AppColors.isDark = true;
            return child ?? const SizedBox.shrink();
          },
          home: _SplashOverlay(
            child: MainShellPage(
              appState: appState,
              bleService: bleService,
              voiceCoach: voiceCoach ?? VoiceCoachService(),
            ),
          ),
        );
      },
    );
  }
}

class _SplashOverlay extends StatefulWidget {
  final Widget child;
  const _SplashOverlay({required this.child});

  @override
  State<_SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<_SplashOverlay>
    with SingleTickerProviderStateMixin {
  static const _splashAsset = AssetImage('assets/splash_logo.png');
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  bool _done = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 72),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 28,
      ),
    ]).animate(_controller);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _done = true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Wait until the splash image is decoded before starting the hold/fade timer.
    precacheImage(_splashAsset, context).whenComplete(() {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_controller.isAnimating && !_done) {
          _controller.forward();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    final logoSize = MediaQuery.sizeOf(context).shortestSide;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _opacity,
              child: ColoredBox(
                color: const Color(0xFF0F1722),
                child: Center(
                  child: Image(
                    image: _splashAsset,
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MainShellPage extends StatefulWidget {
  final AppStateService appState;
  final ProFormBleService bleService;
  final VoiceCoachService voiceCoach;

  const MainShellPage({
    super.key,
    required this.appState,
    required this.bleService,
    required this.voiceCoach,
  });

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final LiveSessionService _liveSession;
  int _selectedIndex = 0;
  Workout? _selectedWorkoutForLandscape;
  bool _userClearedLandscapeWorkout = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _selectedIndex) {
        setState(() => _selectedIndex = _tabController.index);
      }
    });
    _liveSession = LiveSessionService(
      appState: widget.appState,
      bleService: widget.bleService,
      voiceCoach: widget.voiceCoach,
    );
  }

  @override
  void dispose() {
    _liveSession.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSelectWorkout(Workout workout) {
    setState(() {
      _userClearedLandscapeWorkout = false;
      _selectedWorkoutForLandscape = workout;
    });
    _liveSession.selectWorkout(workout);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.appState,
        widget.bleService,
        widget.voiceCoach,
        _liveSession,
      ]),
      builder: (context, _) {
        AppColors.isDark = Theme.of(context).brightness == Brightness.dark;
        final isLandscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;

        // En orientation Paysage : affichage des données live et contrôles uniquement en plein écran
        if (isLandscape) {
          final scheduledNext =
              widget.appState.activeProgram?.nextScheduledSession?.workout;
          final effectiveWorkout = _selectedWorkoutForLandscape ??
              ((!_userClearedLandscapeWorkout && !_liveSession.isRunning)
                  ? scheduledNext
                  : _liveSession.selectedWorkout);
          if (effectiveWorkout != null &&
              !_liveSession.isRunning &&
              _liveSession.selectedWorkout?.id != effectiveWorkout.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted &&
                  !_liveSession.isRunning &&
                  !_userClearedLandscapeWorkout) {
                _liveSession.selectWorkout(effectiveWorkout);
              }
            });
          }
          return LandscapeSessionScreen(
            appState: widget.appState,
            bleService: widget.bleService,
            voiceCoach: widget.voiceCoach,
            liveSession: _liveSession,
            selectedWorkout: effectiveWorkout,
            onClearWorkout: () {
              setState(() {
                _userClearedLandscapeWorkout = true;
                _selectedWorkoutForLandscape = null;
              });
              _liveSession.clearWorkout();
            },
            onSessionSaved: () {
              setState(() {
                _userClearedLandscapeWorkout = false;
                _selectedWorkoutForLandscape = null;
                _selectedIndex = 2;
              });
              _tabController.animateTo(2);
            },
          );
        }

        // Pages du Menu bas (4 onglets : Accueil, Programmes, Historique, Profil)
        final screens = [
          HomeScreen(
            appState: widget.appState,
            bleService: widget.bleService,
            selectedWorkoutForLandscape: _selectedWorkoutForLandscape,
            onSelectWorkoutForLandscape: _onSelectWorkout,
            onGoToProgramTab: () {
              setState(() => _selectedIndex = 1);
              _tabController.animateTo(1);
            },
            onOpenSettings: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    appState: widget.appState,
                    bleService: widget.bleService,
                  ),
                ),
              );
            },
          ),
          ProgramScreen(
            appState: widget.appState,
            selectedWorkoutForLandscape: _selectedWorkoutForLandscape,
            onSelectWorkoutForLandscape: _onSelectWorkout,
          ),
          SessionsHistoryScreen(
            appState: widget.appState,
          ),
          UserProfileScreen(
            appState: widget.appState,
            embeddedInTab: true,
          ),
        ];

        return Scaffold(
          extendBody: true,
          backgroundColor: AppColors.level0,
          appBar: AppBar(
            backgroundColor: AppColors.level0,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: AppSpacing.pageHorizontal,
            toolbarHeight: 64,
            title: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Rameur',
                style: AppTypography.h1(
                  color: AppColors.rose,
                  fontSize: 28,
                  letterSpacing: 1.0,
                ).copyWith(height: 1.0),
              ),
            ),
            actions: [
              // Header Icon : Rower BLE
              IconButton(
                tooltip: widget.bleService.isHardwareConnected
                    ? 'Rameur connecté'
                    : widget.bleService.latestTelemetry.isConnecting
                        ? 'Connexion au rameur...'
                        : 'Connecter le rameur',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: widget.bleService.isHardwareConnected
                        ? AppColors.rose.withValues(alpha: 0.18)
                        : widget.bleService.latestTelemetry.isConnecting
                            ? AppColors.pastelSand
                            : AppColors.level1,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: widget.bleService.isHardwareConnected
                        ? [
                            BoxShadow(
                              color: AppColors.rose.withValues(alpha: 0.4),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    widget.bleService.isHardwareConnected
                        ? Icons.bluetooth_connected
                        : widget.bleService.latestTelemetry.isConnecting
                            ? Icons.bluetooth_searching
                            : Icons.bluetooth_disabled,
                    size: 19,
                    color: widget.bleService.isHardwareConnected
                        ? AppColors.rose
                        : widget.bleService.latestTelemetry.isConnecting
                            ? AppColors.amber
                            : AppColors.textSecondary,
                  ),
                ),
                onPressed: () {
                  if (!widget.bleService.isHardwareConnected &&
                      !widget.bleService.latestTelemetry.isConnecting) {
                    widget.bleService.scanAndConnectHardware();
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          appState: widget.appState,
                          bleService: widget.bleService,
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 4),

              // Header Icon : Landscape Mode Rotation
              IconButton(
                tooltip: 'Basculer en mode paysage (Séance)',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.level1,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Icon(
                    Icons.screen_rotation_rounded,
                    size: 19,
                    color: AppColors.textSecondary,
                  ),
                ),
                onPressed: () {
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.landscapeRight,
                    DeviceOrientation.landscapeLeft,
                  ]);
                },
              ),
              const SizedBox(width: 4),

              // Header Icon : Settings
              IconButton(
                tooltip: 'Paramètres',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.level1,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    size: 19,
                    color: AppColors.textSecondary,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                        appState: widget.appState,
                        bleService: widget.bleService,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: screens,
                ),
              ),
              if (_liveSession.isRunning)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 92,
                  child: SafeArea(
                    top: false,
                    child: _buildPortraitLiveBanner(),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: GlassTabBar.bottom(
                    tabs: [
                      GlassTab(
                        icon: const Icon(CupertinoIcons.house),
                        activeIcon: const Icon(CupertinoIcons.house_fill),
                        label: 'Accueil',
                        glowColor: AppColors.rose,
                      ),
                      GlassTab(
                        icon: const Icon(CupertinoIcons.calendar),
                        activeIcon: const Icon(CupertinoIcons.calendar_today),
                        label: 'Programmes',
                        glowColor: AppColors.rose,
                      ),
                      GlassTab(
                        icon: const Icon(CupertinoIcons.clock),
                        activeIcon: const Icon(CupertinoIcons.clock_fill),
                        label: 'Historique',
                        glowColor: AppColors.rose,
                      ),
                      GlassTab(
                        icon: const Icon(CupertinoIcons.person),
                        activeIcon: const Icon(CupertinoIcons.person_fill),
                        label: 'Profil',
                        glowColor: AppColors.rose,
                      ),
                    ],
                    selectedIndex: _selectedIndex,
                    onTabSelected: (index) {
                      setState(() => _selectedIndex = index);
                      _tabController.animateTo(index);
                    },
                    barHeight: 66,
                    horizontalPadding: 16,
                    verticalPadding: 8,
                    iconSize: 22,
                    labelFontSize: 11,
                    settings: const LiquidGlassSettings(
                      thickness: 22,
                      blur: 16,
                      chromaticAberration: 0.12,
                      lightIntensity: 0.35,
                      refractiveIndex: 1.25,
                      saturation: 1.0,
                      ambientStrength: 0.35,
                      glassColor: Color(0x14162235),
                      backerColor: Color(0x450F1722),
                      bodyMode: GlassBodyMode.clear,
                    ),
                    indicatorSettings: const LiquidGlassSettings(
                      thickness: 16,
                      blur: 10,
                      chromaticAberration: 0.1,
                      lightIntensity: 0.45,
                      refractiveIndex: 1.25,
                      saturation: 1.1,
                      ambientStrength: 0.6,
                      glassColor: Color(0x35E57373),
                      bodyMode: GlassBodyMode.adaptive,
                    ),
                    indicatorColor: AppColors.rose.withValues(alpha: 0.35),
                    selectedIconColor: AppColors.rosePastel,
                    selectedLabelColor: AppColors.rosePastel,
                    unselectedIconColor: AppColors.textSecondary,
                    unselectedLabelColor: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPortraitLiveBanner() {
    final tel = widget.bleService.latestTelemetry;
    final mins = _liveSession.sessionElapsedSeconds ~/ 60;
    final secs = _liveSession.sessionElapsedSeconds % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.level1.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (_liveSession.isPaused ? AppColors.amber : AppColors.green)
              .withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _liveSession.isPaused ? AppColors.amber : AppColors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _liveSession.isPaused
                      ? 'Séance en pause • $timeStr'
                      : 'Enregistrement • $timeStr',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_liveSession.sessionDistanceMeters.round()} m  •  ${tel.watts} W  •  ${tel.cadenceSpm} spm',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _stopAndSavePortraitSession,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.rosePastel,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Terminer',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _stopAndSavePortraitSession() async {
    final summary = _liveSession.stopAndBuildSummary();
    if (summary == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.level1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Terminer la séance ?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Temps : ${summary.durationSeconds ~/ 60}m${(summary.durationSeconds % 60).toString().padLeft(2, '0')}\n'
          'Distance : ${summary.distanceMeters.round()} m\n'
          'Coups : ${summary.strokesCount} • Calories : ${summary.caloriesKcal.round()} kcal',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Ignorer',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppButtons.compact(),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.appState.addSession(
        summary.toWorkoutSession(widget.appState.activeUser.id),
      );
      if (mounted) {
        setState(() {
          _userClearedLandscapeWorkout = false;
          _selectedWorkoutForLandscape = null;
          _selectedIndex = 3;
        });
        _tabController.animateTo(3);
      }
    } else if (mounted) {
      setState(() {
        _userClearedLandscapeWorkout = false;
        _selectedWorkoutForLandscape = null;
      });
    }
    _liveSession.resetAfterSaveOrDiscard();
  }
}

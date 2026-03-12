import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'services/vault_service.dart';
import 'services/drive_backup_service.dart';
import 'services/autofill_bridge.dart';
import 'screens/login_screen.dart';
import 'screens/setup_screen.dart';

// ─────────────────────────────────────────────────
// Auto Backup Logic
// ─────────────────────────────────────────────────

class AutoBackupHelper {
  static bool _isRunning = false;

  /// Check if backup is needed (once per day) and run it.
  static Future<bool> runIfNeeded(VaultService vaultService) async {
    if (_isRunning) return false;

    final config = vaultService.backupConfig;
    if (!config.autoBackupEnabled) return false;
    if (!config.isLoggedIn) return false;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Already backed up today — skip
    if (config.lastBackup != null &&
        config.lastBackup!.isAfter(todayStart)) {
      return false;
    }

    _isRunning = true;
    try {
      final driveService = DriveBackupService(vaultService: vaultService);
      return await driveService.uploadBackupSimple();
    } catch (_) {
      return false;
    } finally {
      _isRunning = false;
    }
  }
}

// ─────────────────────────────────────────────────
// Foreground Task Handler (runs even when app is closed)
// ─────────────────────────────────────────────────

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(AutoBackupTaskHandler());
}

class AutoBackupTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Foreground task started
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    // Called every 15 minutes — check if daily backup is needed
    try {
      final vaultService = VaultService();
      await vaultService.init();
      final success = await AutoBackupHelper.runIfNeeded(vaultService);
      if (success) {
        FlutterForegroundTask.updateService(
          notificationTitle: 'OneShield',
          notificationText: 'Auto backup completed ✓',
        );
        await Future.delayed(const Duration(seconds: 30));
        FlutterForegroundTask.updateService(
          notificationTitle: 'OneShield',
          notificationText: 'Auto backup active',
        );
      }
    } catch (_) {}
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Foreground task destroyed
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {}
}

// ─────────────────────────────────────────────────
// Foreground Task Init & Control
// ─────────────────────────────────────────────────

void _initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'oneshield_auto_backup',
      channelName: 'Auto Backup Service',
      channelDescription: 'Keeps auto backup running for daily protection',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      // Check every 12 hours (43200000 ms)
      eventAction: ForegroundTaskEventAction.repeat(43200000),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

/// Request permissions for foreground task
Future<void> _requestPermissions() async {
  final notifPerm = await FlutterForegroundTask.checkNotificationPermission();
  if (notifPerm != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }

  if (Platform.isAndroid) {
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }
}

/// Start the foreground backup service
Future<void> startAutoBackupService() async {
  await _requestPermissions();
  if (await FlutterForegroundTask.isRunningService) return;

  await FlutterForegroundTask.startService(
    notificationTitle: 'OneShield',
    notificationText: 'Auto backup active',
    callback: startCallback,
  );
}

/// Stop the foreground backup service
Future<void> stopAutoBackupService() async {
  await FlutterForegroundTask.stopService();
}

// ─────────────────────────────────────────────────
// Main App
// ─────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surfaceDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize foreground task
  FlutterForegroundTask.initCommunicationPort();
  _initForegroundTask();

  final vaultService = VaultService();
  await vaultService.init();

  // Start foreground service if auto backup is enabled
  if (vaultService.backupConfig.autoBackupEnabled &&
      vaultService.backupConfig.isLoggedIn) {
    await startAutoBackupService();
  }

  runApp(OneShieldApp(vaultService: vaultService));
}

class OneShieldApp extends StatefulWidget {
  final VaultService vaultService;
  const OneShieldApp({super.key, required this.vaultService});

  @override
  State<OneShieldApp> createState() => _OneShieldAppState();
}

class _OneShieldAppState extends State<OneShieldApp>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  DateTime? _pausedAt;
  static const _autoLockDuration = Duration(seconds: 30);
  Timer? _autoBackupTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // In-app: check every 60s while app is open
    _autoBackupTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _checkAutoBackup(),
    );
    // Check shortly after app start
    Future.delayed(const Duration(seconds: 5), _checkAutoBackup);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoBackupTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null &&
          widget.vaultService.isUnlocked &&
          DateTime.now().difference(_pausedAt!) > _autoLockDuration) {
        widget.vaultService.lock();
        AutofillBridge(vaultService: widget.vaultService).clearCredentials();
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => LoginScreen(vaultService: widget.vaultService),
          ),
          (_) => false,
        );
      }
      _pausedAt = null;
      _checkAutoBackup();
    }
  }

  Future<void> _checkAutoBackup() async {
    final success = await AutoBackupHelper.runIfNeeded(widget.vaultService);
    if (success && mounted) {
      final ctx = _navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.cloud_done, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Auto backup completed'),
              ],
            ),
            backgroundColor: AppTheme.accentGreen.withValues(alpha: 0.9),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: widget.vaultService.isSetUp
          ? LoginScreen(vaultService: widget.vaultService)
          : SetupScreen(vaultService: widget.vaultService),
    );
  }
}

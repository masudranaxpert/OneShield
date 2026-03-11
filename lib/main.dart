import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'services/vault_service.dart';
import 'services/drive_backup_service.dart';
import 'services/autofill_bridge.dart';
import 'screens/login_screen.dart';
import 'screens/setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surfaceDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize vault service
  final vaultService = VaultService();
  await vaultService.init();

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

  // Auto-lock after 30 seconds in background
  static const _autoLockDuration = Duration(seconds: 30);

  // Auto backup scheduler
  Timer? _autoBackupTimer;
  bool _isAutoBackupRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start auto backup scheduler - checks every 60 seconds
    _autoBackupTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _checkAndRunAutoBackup(),
    );
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
        // Lock the vault and clear autofill credentials
        widget.vaultService.lock();
        AutofillBridge(vaultService: widget.vaultService).clearCredentials();
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
                LoginScreen(vaultService: widget.vaultService),
          ),
          (_) => false,
        );
      }
      _pausedAt = null;

      // Check auto backup when app resumes
      _checkAndRunAutoBackup();
    }
  }

  /// Check if it's time for auto backup and run it silently.
  /// Auto backup works regardless of vault lock state because
  /// exported data is already encrypted in the database.
  Future<void> _checkAndRunAutoBackup() async {
    if (_isAutoBackupRunning) return;

    final config = widget.vaultService.backupConfig;

    // Check conditions: enabled + logged in to Drive
    if (!config.autoBackupEnabled) return;
    if (!config.isLoggedIn) return;

    // Parse scheduled backup time (HH:mm format)
    final now = DateTime.now();
    final parts = config.backupTime.split(':');
    if (parts.length != 2) return;
    final scheduledHour = int.tryParse(parts[0]) ?? -1;
    final scheduledMinute = int.tryParse(parts[1]) ?? -1;
    if (scheduledHour < 0 || scheduledMinute < 0) return;

    // Check if current time is at or past the scheduled time today
    final scheduledToday = DateTime(now.year, now.month, now.day,
        scheduledHour, scheduledMinute);
    if (now.isBefore(scheduledToday)) return;


    if (config.lastBackup != null) {
      if (config.lastBackup!.isAfter(scheduledToday)) {
        return; 
      }
    }

    // Run auto backup silently
    _isAutoBackupRunning = true;
    try {
      final driveService =
          DriveBackupService(vaultService: widget.vaultService);
      final success = await driveService.uploadBackupSimple();
      if (success && mounted) {
        // Show a brief notification via SnackBar
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
    } catch (_) {
      // Silent fail for auto backup
    } finally {
      _isAutoBackupRunning = false;
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

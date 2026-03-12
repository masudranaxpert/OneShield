import 'dart:async';
import 'drive_backup_service.dart';
import 'vault_service.dart';

class SyncService {
  final VaultService vaultService;
  late final DriveBackupService _driveService;
  
  bool _isSyncing = false;
  bool _needsSyncAgain = false; // Track if changes happened during sync
  Timer? _debounceTimer;
  Timer? _pollingTimer;

  SyncService({required this.vaultService}) {
    _driveService = DriveBackupService(vaultService: vaultService);
    
    // Listen for local changes to trigger upload/sync
    vaultService.onDataChanged = _onLocalDataChanged;
    
    // Start background polling (every 30 seconds for better responsiveness)
    _startPolling();
  }

  /// Initial sync when app starts or unlocks
  Future<void> initialSync() async {
    if (!vaultService.backupConfig.isLoggedIn) return;
    if (vaultService.backupConfig.cachedMergeFolderId == null) return;
    await performSync();
  }

  /// Background polling every 30 seconds
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (vaultService.backupConfig.isLoggedIn && 
          vaultService.backupConfig.cachedMergeFolderId != null &&
          !_isSyncing) {
        performSync();
      }
    });
  }

  void _onLocalDataChanged() {
    if (!vaultService.backupConfig.isLoggedIn) return;
    if (vaultService.backupConfig.cachedMergeFolderId == null) return;

    // Faster debounce - 2 seconds
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      performSync();
    });
  }

  Future<void> performSync() async {
    if (_isSyncing) {
      _needsSyncAgain = true; // Mark that we need to sync again after current one
      return;
    }
    
    _isSyncing = true;
    _needsSyncAgain = false;
    
    try {
      await _driveService.syncWithCloud();
    } catch (_) {
      // Fail silently, will retry
    } finally {
      _isSyncing = false;
      // If changes happened while we were syncing, start again immediately
      if (_needsSyncAgain) {
        _needsSyncAgain = false;
        performSync();
      }
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _pollingTimer?.cancel();
  }
}

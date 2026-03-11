import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/vault_service.dart';
import '../services/drive_backup_service.dart';
import '../services/autofill_bridge.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VaultService vaultService;

  const SettingsScreen({super.key, required this.vaultService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  late DriveBackupService _driveService;
  late AutofillBridge _autofillBridge;
  bool _isBackingUp = false;
  bool _isLoggingIn = false;
  bool _isRestoring = false;
  bool _isAutofillEnabled = false;

  @override
  void initState() {
    super.initState();
    _driveService = DriveBackupService(vaultService: widget.vaultService);
    _autofillBridge = AutofillBridge(vaultService: widget.vaultService);
    _checkAutofillStatus();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _checkAutofillStatus() async {
    final enabled = await _autofillBridge.isAutofillEnabled();
    if (mounted) setState(() => _isAutofillEnabled = enabled);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh autofill status when returning from system settings
    if (state == AppLifecycleState.resumed) {
      _checkAutofillStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _driveService.cancelServer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backupConfig = widget.vaultService.backupConfig;
    final masterConfig = widget.vaultService.masterConfig;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage your vault settings',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 28),

          // Security Section
          _buildSectionHeader('Security', Icons.security),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSettingToggle(
                  'Device Authentication',
                  'Use PIN, pattern, fingerprint or face to unlock',
                  Icons.lock_person,
                  masterConfig?.biometricEnabled ?? false,
                  (value) async {
                    await widget.vaultService.setBiometric(value);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Autofill Section
          _buildSectionHeader('Autofill', Icons.auto_fix_high),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isAutofillEnabled
                            ? AppTheme.accentGreen.withValues(alpha: 0.15)
                            : AppTheme.accentOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _isAutofillEnabled ? Icons.check_circle : Icons.warning_amber,
                        color: _isAutofillEnabled ? AppTheme.accentGreen : AppTheme.accentOrange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isAutofillEnabled
                                ? 'OneShield is your autofill provider'
                                : 'Autofill NOT enabled',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isAutofillEnabled
                                ? 'Passwords will auto-fill in browsers & apps'
                                : 'OneShield must be selected as system autofill provider',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!_isAutofillEnabled) ...[
                  SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      text: 'Set as Autofill Provider',
                      icon: Icons.settings,
                      gradient: const LinearGradient(
                        colors: [AppTheme.accentCyan, AppTheme.accentPurple],
                      ),
                      onPressed: () async {
                        await _autofillBridge.openAutofillSettings();
                        // Wait and recheck multiple times
                        for (var i = 0; i < 5; i++) {
                          await Future.delayed(const Duration(seconds: 2));
                          await _checkAutofillStatus();
                          if (_isAutofillEnabled) break;
                        }
                      },
                    ),
                  ),
                ],
                if (_isAutofillEnabled) ...[
                  SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      text: 'Sync Passwords Now',
                      icon: Icons.sync,
                      gradient: const LinearGradient(
                        colors: [AppTheme.accentGreen, AppTheme.accentCyan],
                      ),
                      onPressed: () async {
                        await _autofillBridge.syncCredentials();
                        if (mounted) {
                          _showSnackBar('Passwords synced for autofill!');
                        }
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Diagnostics button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showAutofillDebugInfo,
                    icon: const Icon(Icons.bug_report, size: 18),
                    label: const Text('Autofill Diagnostics'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.surfaceLight),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Cloud Backup Section
          _buildSectionHeader('Cloud Backup', Icons.cloud_outlined),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: backupConfig.isLoggedIn
                            ? AppTheme.accentGreen.withValues(alpha: 0.15)
                            : AppTheme.accentOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        backupConfig.isLoggedIn
                            ? Icons.cloud_done
                            : Icons.cloud_off,
                        color: backupConfig.isLoggedIn
                            ? AppTheme.accentGreen
                            : AppTheme.accentOrange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            backupConfig.isLoggedIn
                                ? 'Google Drive Connected'
                                : 'Not Connected',
                            style: TextStyle(
                              color: backupConfig.isLoggedIn
                                  ? AppTheme.accentGreen
                                  : AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          if (backupConfig.isLoggedIn &&
                              backupConfig.userEmail != null)
                            Text(
                              backupConfig.userEmail!,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            )
                          else if (backupConfig.lastBackup != null)
                            Text(
                              'Last backup: ${_formatDate(backupConfig.lastBackup!)}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Storage quota display
                if (backupConfig.isLoggedIn &&
                    backupConfig.storageUsed != null &&
                    backupConfig.storageLimit != null &&
                    backupConfig.storageLimit! > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Storage',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${backupConfig.storageUsedFormatted} / ${backupConfig.storageLimitFormatted}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: backupConfig.storageUsedPercent,
                            minHeight: 6,
                            backgroundColor: AppTheme.surfaceLight,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              backupConfig.storageUsedPercent > 0.9
                                  ? AppTheme.accentRed
                                  : backupConfig.storageUsedPercent > 0.7
                                      ? AppTheme.accentOrange
                                      : AppTheme.accentGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (backupConfig.isLoggedIn && backupConfig.lastBackup != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule,
                            size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          'Last backup: ${_formatDate(backupConfig.lastBackup!)}',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                if (!backupConfig.isLoggedIn) ...[
                  _buildDriveLoginSection(),
                ] else ...[
                  // Auto backup toggle
                  _buildSettingToggle(
                    'Auto Backup',
                    'Backup automatically at ${backupConfig.backupTime}',
                    Icons.schedule,
                    backupConfig.autoBackupEnabled,
                    (value) async {
                      backupConfig.autoBackupEnabled = value;
                      await widget.vaultService.saveBackupConfig(backupConfig);
                      setState(() {});
                    },
                  ),
                  const Divider(color: AppTheme.surfaceLight, height: 24),
                  // Backup time selector
                  _buildSettingAction(
                    'Backup Time',
                    backupConfig.backupTime,
                    Icons.access_time,
                    () => _selectBackupTime(),
                  ),
                  const Divider(color: AppTheme.surfaceLight, height: 24),
                  // Manual backup
                  _buildSettingAction(
                    'Backup Now',
                    'Upload to Google Drive',
                    Icons.cloud_upload_outlined,
                    _isBackingUp ? null : _performBackup,
                    trailing: _isBackingUp
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accentCyan,
                            ),
                          )
                        : null,
                  ),
                  const Divider(color: AppTheme.surfaceLight, height: 24),
                  // Restore from cloud
                  _buildSettingAction(
                    'Restore from Cloud',
                    'Download backup from Drive',
                    Icons.cloud_download_outlined,
                    _isRestoring ? null : _showCloudRestoreDialog,
                    trailing: _isRestoring
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accentCyan,
                            ),
                          )
                        : null,
                  ),
                  const Divider(color: AppTheme.surfaceLight, height: 24),
                  // Refresh user info
                  _buildSettingAction(
                    'Refresh Info',
                    'Update email & storage info',
                    Icons.refresh,
                    _refreshUserInfo,
                  ),
                  const Divider(color: AppTheme.surfaceLight, height: 24),
                  // Logout
                  _buildSettingAction(
                    'Disconnect',
                    'Logout from Google Drive',
                    Icons.logout,
                    _logoutDrive,
                    isDestructive: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Local Backup Section
          _buildSectionHeader('Local Backup', Icons.folder_outlined),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSettingAction(
                  'Export Location',
                  widget.vaultService.backupConfig.localBackupPath ??
                      'Not set (uses app documents)',
                  Icons.folder_open_outlined,
                  _setExportLocation,
                ),
                if (widget.vaultService.backupConfig.localBackupPath != null) ...[
                  const Divider(color: AppTheme.surfaceLight, height: 24),
                  _buildSettingAction(
                    'Clear Export Location',
                    'Reset to default app documents',
                    Icons.clear,
                    _clearExportLocation,
                    isDestructive: true,
                  ),
                ],
                const Divider(color: AppTheme.surfaceLight, height: 24),
                _buildSettingAction(
                  'Export Backup',
                  'Save encrypted backup file',
                  Icons.file_download_outlined,
                  _exportLocalBackup,
                ),
                const Divider(color: AppTheme.surfaceLight, height: 24),
                _buildSettingAction(
                  'Import Backup',
                  'Restore from backup file',
                  Icons.file_upload_outlined,
                  _importLocalBackup,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // About Section
          _buildSectionHeader('About', Icons.info_outline),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSettingAction(
                  AppConstants.appName,
                  'Version ${AppConstants.appVersion}',
                  Icons.shield,
                  null,
                ),
                const Divider(color: AppTheme.surfaceLight, height: 24),
                _buildSettingAction(
                  'Lock Vault',
                  'Logout and lock',
                  Icons.lock_outline,
                  _lockVault,
                  isDestructive: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDriveLoginSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Connect Google Drive to enable cloud backup. '
          'Your backups are encrypted with your master password.\n\n'
          'After clicking Connect, sign in with Google and copy the '
          'authorization code shown in the browser.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        GradientButton(
          text: 'Connect Google Drive',
          icon: Icons.cloud,
          isLoading: _isLoggingIn,
          onPressed: _startDriveLogin,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.accentCyan),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingToggle(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: AppTheme.accentCyan,
          activeTrackColor: AppTheme.accentCyan.withValues(alpha: 0.3),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSettingAction(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? onTap, {
    bool isDestructive = false,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive
                  ? AppTheme.accentRed
                  : AppTheme.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive
                          ? AppTheme.accentRed
                          : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right,
                  color: AppTheme.textMuted.withValues(alpha: 0.5),
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }

  // --- Drive Login ---
  Future<void> _startDriveLogin() async {
    setState(() => _isLoggingIn = true);

    try {
      final authUrl = _driveService.getAuthUrl();

      // Start callback server to receive redirect
      final codeFuture = _driveService.startCallbackServer();

      // Open browser for auth
      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      // Wait for callback from server
      final code = await codeFuture;

      if (code != null && code.isNotEmpty) {
        final success = await _driveService.exchangeCode(code);
        if (success && mounted) {
          _showSnackBar('Google Drive connected successfully!');
        } else if (mounted) {
          _showSnackBar('Failed to connect. Please try again.');
        }
      } else if (mounted) {
        // Server failed or timed out - show manual code input
        setState(() => _isLoggingIn = false);
        _showManualCodeDialog();
        return;
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error during login: $e');
      }
    }

    if (mounted) setState(() => _isLoggingIn = false);
  }

  /// Fallback: show dialog for manual code paste
  Future<void> _showManualCodeDialog() async {
    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Authorization Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If the automatic redirect did not work, '
              'copy the authorization code from the browser and paste it here.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
              decoration: const InputDecoration(
                hintText: 'Paste authorization code here',
                prefixIcon: Icon(Icons.vpn_key, size: 20),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final c = codeController.text.trim();
              if (c.isNotEmpty) {
                Navigator.pop(ctx, c);
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (code == null || code.isEmpty || !mounted) return;

    setState(() => _isLoggingIn = true);

    final success = await _driveService.exchangeCode(code);
    if (success && mounted) {
      _showSnackBar('Google Drive connected successfully!');
    } else if (mounted) {
      _showSnackBar('Failed to connect. Check the code and try again.');
    }

    if (mounted) setState(() => _isLoggingIn = false);
  }

  // --- Refresh User Info ---
  Future<void> _refreshUserInfo() async {
    _showSnackBar('Refreshing account info...');
    await _driveService.fetchUserInfo();
    if (mounted) {
      setState(() {});
      _showSnackBar('Account info updated!');
    }
  }

  // --- Backup ---
  Future<void> _performBackup() async {
    setState(() => _isBackingUp = true);

    final success = await _driveService.uploadBackupSimple();

    if (mounted) {
      if (success) {
        _showSnackBar('Backup uploaded successfully!');
      } else {
        _showSnackBar('Backup failed. Please try again.');
      }
      setState(() => _isBackingUp = false);
    }
  }

  // --- Cloud Restore ---
  Future<void> _showCloudRestoreDialog() async {
    setState(() => _isRestoring = true);

    final backups = await _driveService.listBackups();

    if (!mounted) return;
    setState(() => _isRestoring = false);

    if (backups.isEmpty) {
      _showSnackBar('No backups found in Google Drive.');
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Backup'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: backups.length,
            itemBuilder: (_, index) {
              final backup = backups[index];
              return ListTile(
                leading: const Icon(Icons.backup,
                    color: AppTheme.accentCyan),
                title: Text(
                  backup['name'] ?? 'Unknown',
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  backup['createdTime'] != null
                      ? _formatDate(
                          DateTime.parse(backup['createdTime']))
                      : '',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => Navigator.pop(ctx, backup['id']),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected == null) return;

    // Download and restore
    setState(() => _isRestoring = true);

    final content = await _driveService.downloadBackup(selected);
    if (content != null) {
      final count = await widget.vaultService.importData(content);
      if (mounted) {
        if (count >= 0) {
          _showSnackBar('Restored $count entries from backup!');
        } else {
          _showSnackBar('Failed to restore backup.');
        }
      }
    } else if (mounted) {
      _showSnackBar('Failed to download backup.');
    }

    if (mounted) setState(() => _isRestoring = false);
  }

  // --- Logout Drive ---
  Future<void> _logoutDrive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Google Drive?'),
        content: const Text(
            'You will need to login again to use cloud backup.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _driveService.logout();
      setState(() {});
      if (mounted) _showSnackBar('Google Drive disconnected.');
    }
  }

  // --- Set Export Location ---
  Future<void> _setExportLocation() async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Export Location',
      );

      if (selectedDirectory != null && mounted) {
        final config = widget.vaultService.backupConfig;
        config.localBackupPath = selectedDirectory;
        await widget.vaultService.saveBackupConfig(config);
        setState(() {});
        _showSnackBar('Export location set: $selectedDirectory');
      }
    } catch (e) {
      _showSnackBar('Failed to set export location');
    }
  }

  // --- Clear Export Location ---
  Future<void> _clearExportLocation() async {
    final config = widget.vaultService.backupConfig;
    config.localBackupPath = null;
    await widget.vaultService.saveBackupConfig(config);
    setState(() {});
    _showSnackBar('Export location reset to default');
  }

  // --- Local Backup ---
  Future<void> _exportLocalBackup() async {
    try {
      final path = await _driveService.saveLocalBackup();
      if (path != null && mounted) {
        _showSnackBar('Backup saved to: $path');
      } else if (mounted) {
        _showSnackBar('Failed to create backup');
      }
    } catch (e) {
      _showSnackBar('Failed to create backup');
    }
  }

  Future<void> _importLocalBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;

      final file = File(path);
      final content = await file.readAsString();

      final count = await widget.vaultService.importData(content);
      if (mounted) {
        if (count >= 0) {
          _showSnackBar('Imported $count new entries!');
        } else {
          _showSnackBar('Invalid backup file format.');
        }
      }
    } catch (e) {
      _showSnackBar('Error reading backup file');
    }
  }

  // --- Backup Time ---
  Future<void> _selectBackupTime() async {
    final config = widget.vaultService.backupConfig;
    final parts = config.backupTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 2,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (selected != null) {
      config.backupTime =
          '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
      await widget.vaultService.saveBackupConfig(config);
      setState(() {});
    }
  }

  // --- Lock ---
  void _lockVault() {
    widget.vaultService.lock();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(vaultService: widget.vaultService),
      ),
      (_) => false,
    );
  }

  Future<void> _showAutofillDebugInfo() async {
    final info = await _autofillBridge.debugAutofill();
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button
              Row(
                children: [
                  const Icon(Icons.bug_report, color: AppTheme.accentCyan, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Autofill Diagnostics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Status rows
              _debugRow('Autofill Supported', info['autofillSupported']),
              _debugRow('OneShield Selected', info['hasEnabledServices']),
              _debugRow('Autofill Enabled', info['isEnabled']),
              _debugRow('Stored Credentials', info['storedCredentialsCount']),
              _debugRow('Android API', info['androidVersion']),
              if (info['storageError'] != null)
                _debugRow('Storage Error', info['storageError']),
              const SizedBox(height: 16),
              // Open settings button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _autofillBridge.openAutofillSettings();
                  },
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Open Autofill Settings'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Refresh status after dialog is dismissed
    _checkAutofillStatus();
  }

  Widget _debugRow(String label, dynamic value) {
    final isGood = value == true || (value is int && value > 0);
    final isBad = value == false || value == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isGood ? Icons.check_circle : (isBad ? Icons.cancel : Icons.info),
            size: 16,
            color: isGood ? AppTheme.accentGreen : (isBad ? AppTheme.accentRed : AppTheme.textMuted),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              '$value',
              style: TextStyle(
                color: isGood ? AppTheme.accentGreen : (isBad ? AppTheme.accentRed : AppTheme.textPrimary),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

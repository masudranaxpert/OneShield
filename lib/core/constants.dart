// -------------------------------------------------------
// App-wide constants.
// Change values here and they propagate everywhere.
// -------------------------------------------------------

class AppConstants {
  AppConstants._(); // prevent instantiation

  // ── App Identity ──────────────────────────────────────
  static const String appName = 'OneShield';
  static const String appTagline = 'Your secure password manager';
  static const String appVersion = '1.0.0';
  static const String logoAsset = 'assets/logo/OneShield_logo.png';

  // ── Backup Defaults ───────────────────────────────────
  static const String defaultDriveFolder = 'OneShield_Backups';
  static const String backupFilePrefix = 'oneshield_backup';
  static const String backupFileExtension = '.vpb';
  static const String defaultBackupTime = '02:00';

  // ── Google OAuth (rclone credentials) ─────────────────
  static const String defaultClientId =
      '202264815644.apps.googleusercontent.com';
  static const String defaultClientSecret = 'X4Z3ca8xfWDb1Voo-F9a7ZxJ';
  static const String oauthRedirectUri = 'http://localhost:53682/';
  static const int oauthPort = 53682;
  static const int oauthTimeoutMinutes = 3;

  // ── Security ──────────────────────────────────────────
  static const int minPasswordLength = 8;
  static const int maxRecoveryAttemptsPerDay = 10;
  static const int requiredSecurityQuestions = 3;
  static const int maxOldBackupsToKeep = 5;
  static const int defaultPasswordLength = 20;

  // ── Biometric ─────────────────────────────────────────
  static const String biometricReason = 'Unlock $appName';
}

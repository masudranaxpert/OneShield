import 'package:hive/hive.dart';
import '../core/constants.dart';

class BackupConfig extends HiveObject {
  @HiveField(0)
  String? refreshToken;

  @HiveField(1)
  String? accessToken;

  @HiveField(2)
  DateTime? tokenExpiry;

  @HiveField(3)
  String backupTime;

  @HiveField(4)
  bool autoBackupEnabled;

  @HiveField(5)
  DateTime? lastBackup;

  @HiveField(6)
  String? driveFolder;

  @HiveField(7)
  String clientId;

  @HiveField(8)
  String clientSecret;

  @HiveField(9)
  String? userEmail;

  @HiveField(10)
  String? userName;

  @HiveField(11)
  int? storageUsed; // bytes

  @HiveField(12)
  int? storageLimit; // bytes

  @HiveField(13)
  String? localBackupPath;

  // Cached Google Drive folder IDs to prevent duplicate folder creation
  @HiveField(14)
  String? cachedParentFolderId;

  @HiveField(15)
  String? cachedBackupFolderId;

  @HiveField(16)
  String? cachedMergeFolderId;

  // Windows: lock vault when minimized to tray
  @HiveField(17)
  bool lockOnMinimize;

  BackupConfig({
    this.refreshToken,
    this.accessToken,
    this.tokenExpiry,
    this.backupTime = AppConstants.defaultBackupTime,
    this.autoBackupEnabled = false,
    this.lastBackup,
    this.driveFolder = AppConstants.defaultDriveFolder,
    this.clientId = AppConstants.defaultClientId,
    this.clientSecret = AppConstants.defaultClientSecret,
    this.userEmail,
    this.userName,
    this.storageUsed,
    this.storageLimit,
    this.localBackupPath,
    this.cachedParentFolderId,
    this.cachedBackupFolderId,
    this.cachedMergeFolderId,
    this.lockOnMinimize = true, // Default: locked for security
  });

  bool get isLoggedIn => refreshToken != null && refreshToken!.isNotEmpty;

  bool get isTokenExpired =>
      tokenExpiry == null || DateTime.now().isAfter(tokenExpiry!);

  /// Format storage size to human readable
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get storageUsedFormatted =>
      storageUsed != null ? formatBytes(storageUsed!) : 'Unknown';

  String get storageLimitFormatted =>
      storageLimit != null ? formatBytes(storageLimit!) : 'Unknown';

  double get storageUsedPercent {
    if (storageUsed == null || storageLimit == null || storageLimit == 0) {
      return 0;
    }
    return (storageUsed! / storageLimit!).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'refreshToken': refreshToken,
        'accessToken': accessToken,
        'tokenExpiry': tokenExpiry?.toIso8601String(),
        'backupTime': backupTime,
        'autoBackupEnabled': autoBackupEnabled,
        'lastBackup': lastBackup?.toIso8601String(),
        'driveFolder': driveFolder,
        'clientId': clientId,
        'clientSecret': clientSecret,
        'userEmail': userEmail,
        'userName': userName,
        'storageUsed': storageUsed,
        'storageLimit': storageLimit,
        'localBackupPath': localBackupPath,
        'cachedParentFolderId': cachedParentFolderId,
        'cachedBackupFolderId': cachedBackupFolderId,
        'cachedMergeFolderId': cachedMergeFolderId,
        'lockOnMinimize': lockOnMinimize,
      };

  factory BackupConfig.fromJson(Map<String, dynamic> json) => BackupConfig(
        refreshToken: json['refreshToken'],
        accessToken: json['accessToken'],
        tokenExpiry: json['tokenExpiry'] != null
            ? DateTime.parse(json['tokenExpiry'])
            : null,
        backupTime: json['backupTime'] ?? AppConstants.defaultBackupTime,
        autoBackupEnabled: json['autoBackupEnabled'] ?? false,
        lastBackup: json['lastBackup'] != null
            ? DateTime.parse(json['lastBackup'])
            : null,
        driveFolder: json['driveFolder'] ?? AppConstants.defaultDriveFolder,
        clientId:
            json['clientId'] ?? AppConstants.defaultClientId,
        clientSecret: json['clientSecret'] ?? AppConstants.defaultClientSecret,
        userEmail: json['userEmail'],
        userName: json['userName'],
        storageUsed: json['storageUsed'],
        storageLimit: json['storageLimit'],
        localBackupPath: json['localBackupPath'],
        cachedParentFolderId: json['cachedParentFolderId'],
        cachedBackupFolderId: json['cachedBackupFolderId'],
        cachedMergeFolderId: json['cachedMergeFolderId'],
        lockOnMinimize: json['lockOnMinimize'] ?? true,
      );
}

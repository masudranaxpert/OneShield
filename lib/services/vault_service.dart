import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/vault_entry.dart';
import '../models/vault_entry.g.dart';
import '../models/master_config.dart';
import '../models/master_config.g.dart';
import '../models/backup_config.dart';
import '../models/backup_config.g.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'crypto_service.dart';

/// Manages all local storage operations using Hive.
class VaultService {
  static const String _vaultBoxName = 'vault_entries';
  static const String _configBoxName = 'master_config';
  static const String _backupBoxName = 'backup_config';
  static const String _hiveEncryptionKeyName = 'oneshield_hive_encryption_key';

  /// Predefined security questions for password recovery
  static const List<String> predefinedSecurityQuestions = [
    'What is the name of your first pet?',
    'What city were you born in?',
    'What is your mother\'s maiden name?',
    'What was the name of your first school?',
    'What is your favorite movie?',
    'What is the name of your childhood best friend?',
    'What is your favorite food?',
    'What was the make of your first car?',
    'What is your father\'s middle name?',
    'What street did you grow up on?',
    'What is the name of your favorite teacher?',
    'What is the name of the hospital where you were born?',
    'What was your childhood nickname?',
    'What is your favorite sports team?',
    'What is the middle name of your oldest sibling?',
  ];

  late Box<VaultEntry> _vaultBox;
  late Box<MasterConfig> _configBox;
  late Box<BackupConfig> _backupBox;

  Uint8List? _currentKey;
  String? _currentIV;

  bool get isUnlocked => _currentKey != null;

  final _uuid = const Uuid();

  /// Get or create Hive encryption key from Android Keystore
  static Future<List<int>> _getHiveEncryptionKey() async {
    const secureStorage = FlutterSecureStorage();
    final existingKey = await secureStorage.read(key: _hiveEncryptionKeyName);

    if (existingKey != null) {
      return base64Decode(existingKey);
    }

    // Generate a new 256-bit key for Hive encryption
    final newKey = Hive.generateSecureKey();
    await secureStorage.write(
      key: _hiveEncryptionKeyName,
      value: base64Encode(newKey),
    );
    return newKey;
  }

  /// Initialize Hive and register adapters
  Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(VaultEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(MasterConfigAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(SecurityQuestionAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(BackupConfigAdapter());
    }

    // Get encryption key from hardware-backed secure storage
    final encryptionKey = await _getHiveEncryptionKey();
    final cipher = HiveAesCipher(encryptionKey);

    // Check if migration has been done
    const secureStorage = FlutterSecureStorage();
    final migrationDone = await secureStorage.read(key: 'hive_encrypted_v1');

    if (migrationDone == 'true') {
      // Already migrated, open encrypted boxes directly
      _vaultBox = await Hive.openBox<VaultEntry>(
        _vaultBoxName,
        encryptionCipher: cipher,
      );
      _configBox = await Hive.openBox<MasterConfig>(
        _configBoxName,
        encryptionCipher: cipher,
      );
      _backupBox = await Hive.openBox<BackupConfig>(
        _backupBoxName,
        encryptionCipher: cipher,
      );
    } else {
      // First time with encryption: try to migrate old data
      await _migrateToEncryptedBoxes(cipher);
      await secureStorage.write(key: 'hive_encrypted_v1', value: 'true');
    }
  }

  /// Migrate from unencrypted to encrypted Hive boxes
  Future<void> _migrateToEncryptedBoxes(HiveAesCipher cipher) async {
    // Try reading old unencrypted data
    List<Map<String, dynamic>> vaultJsonList = [];
    List<Map<String, dynamic>> configJsonList = [];

    try {
      final oldVault = await Hive.openBox<VaultEntry>(_vaultBoxName);
      final oldConfig = await Hive.openBox<MasterConfig>(_configBoxName);
      final oldBackup = await Hive.openBox<BackupConfig>(_backupBoxName);

      vaultJsonList = oldVault.values.map((e) => e.toJson()).toList();
      configJsonList = oldConfig.values.map((e) => e.toJson()).toList();

      await oldVault.close();
      await oldConfig.close();
      await oldBackup.close();

      // Delete old unencrypted boxes
      await Hive.deleteBoxFromDisk(_vaultBoxName);
      await Hive.deleteBoxFromDisk(_configBoxName);
      await Hive.deleteBoxFromDisk(_backupBoxName);
    } catch (e) {
      // No old data or already cleaned up
    }

    // Open new encrypted boxes
    _vaultBox = await Hive.openBox<VaultEntry>(
      _vaultBoxName,
      encryptionCipher: cipher,
    );
    _configBox = await Hive.openBox<MasterConfig>(
      _configBoxName,
      encryptionCipher: cipher,
    );
    _backupBox = await Hive.openBox<BackupConfig>(
      _backupBoxName,
      encryptionCipher: cipher,
    );

    // Copy old data to encrypted boxes
    for (final json in vaultJsonList) {
      await _vaultBox.add(VaultEntry.fromJson(json));
    }
    for (final json in configJsonList) {
      await _configBox.add(MasterConfig.fromJson(json));
    }
  }

  /// Check if master password is set up
  bool get isSetUp => _configBox.isNotEmpty;

  /// Get master config
  MasterConfig? get masterConfig =>
      _configBox.isNotEmpty ? _configBox.getAt(0) : null;

  /// Get backup config
  BackupConfig get backupConfig {
    if (_backupBox.isEmpty) {
      final config = BackupConfig();
      _backupBox.add(config);
      return config;
    }
    return _backupBox.getAt(0)!;
  }

  /// Save backup config
  Future<void> saveBackupConfig(BackupConfig config) async {
    if (_backupBox.isEmpty) {
      await _backupBox.add(config);
    } else {
      await _backupBox.putAt(0, config);
    }
  }

  /// Set up master password with security questions
  Future<bool> setupMasterPassword(
    String masterPassword,
    List<Map<String, String>> questionsAndAnswers,
  ) async {
    try {
      final salt = CryptoService.generateSalt();
      final iv = CryptoService.generateIV();
      final passwordHash = CryptoService.hashPassword(masterPassword, salt);

      // Create security questions with hashed answers
      final securityQuestions = questionsAndAnswers.map((qa) {
        return SecurityQuestion(
          question: qa['question']!,
          answerHash: CryptoService.hashAnswer(qa['answer']!),
        );
      }).toList();

      // Derive key from master password
      final masterKey = CryptoService.deriveKey(masterPassword, salt);

      // Also encrypt the master key with security answers for recovery
      final answers =
          questionsAndAnswers.map((qa) => qa['answer']!).toList();
      final recoveryKey =
          CryptoService.deriveKeyFromAnswers(answers, salt);
      final encryptedMasterKey = CryptoService.encryptData(
        base64Encode(masterKey),
        recoveryKey,
        iv,
      );

      final config = MasterConfig(
        passwordHash: passwordHash,
        salt: salt,
        iv: iv,
        securityQuestions: securityQuestions,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        encryptedMasterKey: encryptedMasterKey,
      );

      await _configBox.clear();
      await _configBox.add(config);

      _currentKey = masterKey;
      _currentIV = iv;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Verify master password and unlock vault
  bool unlock(String masterPassword) {
    final config = masterConfig;
    if (config == null) return false;

    final hash = CryptoService.hashPassword(masterPassword, config.salt);
    if (hash != config.passwordHash) return false;

    _currentKey = CryptoService.deriveKey(masterPassword, config.salt);
    _currentIV = config.iv;

    // Update last login
    config.lastLogin = DateTime.now();
    config.save();

    return true;
  }


  bool recoverWithAnswers(List<Map<String, String>> questionAnswerPairs) {
    final config = masterConfig;
    if (config == null) return false;

    if (questionAnswerPairs.length != config.securityQuestions.length) {
      return false;
    }

    final matchedIndices = <int>{};

    for (final pair in questionAnswerPairs) {
      final question = pair['question']!;
      final answer = pair['answer']!;
      final ansHash = CryptoService.hashAnswer(answer);

      bool found = false;
      for (int i = 0; i < config.securityQuestions.length; i++) {
        if (matchedIndices.contains(i)) continue;
        if (config.securityQuestions[i].question == question &&
            config.securityQuestions[i].answerHash == ansHash) {
          matchedIndices.add(i);
          found = true;
          break;
        }
      }
      if (!found) return false;
    }

    if (matchedIndices.length != config.securityQuestions.length) return false;

    // Derive key from answers (in the original stored order for key derivation)
    try {
      // Reorder answers to match stored question order
      final orderedAnswers = List<String>.filled(config.securityQuestions.length, '');
      for (final pair in questionAnswerPairs) {
        for (int i = 0; i < config.securityQuestions.length; i++) {
          if (config.securityQuestions[i].question == pair['question']) {
            orderedAnswers[i] = pair['answer']!;
            break;
          }
        }
      }

      final recoveryKey =
          CryptoService.deriveKeyFromAnswers(orderedAnswers, config.salt);
      final decryptedMasterKeyBase64 = CryptoService.decryptData(
        config.encryptedMasterKey!,
        recoveryKey,
        config.iv,
      );
      _currentKey = base64Decode(decryptedMasterKeyBase64);
      _currentIV = config.iv;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if recovery attempts are allowed today
  bool canAttemptRecovery() {
    final config = masterConfig;
    if (config == null) return false;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (config.lastRecoveryDate != today) {
      // New day, reset counter
      return true;
    }
    return config.recoveryAttemptsToday < AppConstants.maxRecoveryAttemptsPerDay;
  }

  /// Get remaining recovery attempts for today
  int getRemainingRecoveryAttempts() {
    final config = masterConfig;
    if (config == null) return 0;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (config.lastRecoveryDate != today) {
      return AppConstants.maxRecoveryAttemptsPerDay;
    }
    return (AppConstants.maxRecoveryAttemptsPerDay - config.recoveryAttemptsToday)
        .clamp(0, AppConstants.maxRecoveryAttemptsPerDay);
  }

  /// Increment recovery attempt counter
  Future<void> _incrementRecoveryAttempt() async {
    final config = masterConfig;
    if (config == null) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (config.lastRecoveryDate != today) {
      config.recoveryAttemptsToday = 1;
      config.lastRecoveryDate = today;
    } else {
      config.recoveryAttemptsToday++;
    }
    await config.save();
  }

  /// Recover master password using security question-answer pairs (with rate limiting)
  Future<Map<String, dynamic>> recoverWithAnswersLimited(List<Map<String, String>> questionAnswerPairs) async {
    if (!canAttemptRecovery()) {
      return {
        'success': false,
        'error': 'limit_exceeded',
        'remaining': 0,
      };
    }

    await _incrementRecoveryAttempt();

    final success = recoverWithAnswers(questionAnswerPairs);
    return {
      'success': success,
      'error': success ? null : 'wrong_answers',
      'remaining': getRemainingRecoveryAttempts(),
    };
  }

  /// Lock the vault
  void lock() {
    _currentKey = null;
    _currentIV = null;
  }

  /// Add a new vault entry
  Future<VaultEntry> addEntry({
    required String title,
    required String category,
    required Map<String, String> fields,
    String? iconName,
    List<String> tags = const [],
  }) async {
    final encryptedFields = _encryptFields(fields);
    final entry = VaultEntry(
      id: _uuid.v4(),
      title: title,
      category: category,
      fields: encryptedFields,
      iconName: iconName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tags: tags,
    );
    await _vaultBox.add(entry);
    return entry;
  }

  /// Update an existing entry
  Future<void> updateEntry(VaultEntry entry, Map<String, String> newFields) async {
    entry.fields = _encryptFields(newFields);
    entry.updatedAt = DateTime.now();
    await entry.save();
  }

  /// Update entry metadata (title, category, etc.)
  Future<void> updateEntryMeta(VaultEntry entry, {
    String? title,
    String? category,
    String? iconName,
    bool? isFavorite,
    List<String>? tags,
  }) async {
    if (title != null) entry.title = title;
    if (category != null) entry.category = category;
    if (iconName != null) entry.iconName = iconName;
    if (isFavorite != null) entry.isFavorite = isFavorite;
    if (tags != null) entry.tags = tags;
    entry.updatedAt = DateTime.now();
    await entry.save();
  }

  /// Delete an entry
  Future<void> deleteEntry(VaultEntry entry) async {
    await entry.delete();
  }

  /// Get all entries
  List<VaultEntry> getAllEntries() {
    return _vaultBox.values.toList();
  }

  /// Get entries by category
  List<VaultEntry> getEntriesByCategory(String category) {
    return _vaultBox.values
        .where((e) => e.category == category)
        .toList();
  }

  /// Get favorite entries
  List<VaultEntry> getFavorites() {
    return _vaultBox.values.where((e) => e.isFavorite).toList();
  }

  /// Search entries
  List<VaultEntry> searchEntries(String query) {
    final q = query.toLowerCase();
    return _vaultBox.values.where((e) {
      return e.title.toLowerCase().contains(q) ||
          e.tags.any((t) => t.toLowerCase().contains(q)) ||
          e.category.toLowerCase().contains(q);
    }).toList();
  }

  /// Decrypt fields of an entry
  Map<String, String> decryptFields(VaultEntry entry) {
    if (_currentKey == null || _currentIV == null) return {};
    final decrypted = <String, String>{};
    for (final kv in entry.fields.entries) {
      decrypted[kv.key] =
          CryptoService.decryptData(kv.value, _currentKey!, _currentIV!);
    }
    return decrypted;
  }

  /// Encrypt fields
  Map<String, String> _encryptFields(Map<String, String> fields) {
    if (_currentKey == null || _currentIV == null) return fields;
    final encrypted = <String, String>{};
    for (final kv in fields.entries) {
      encrypted[kv.key] =
          CryptoService.encryptData(kv.value, _currentKey!, _currentIV!);
    }
    return encrypted;
  }

  /// Export all data as encrypted JSON
  String exportData() {
    final entries = _vaultBox.values.map((e) => e.toJson()).toList();
    final config = masterConfig?.toJson();
    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'config': config,
      'entries': entries,
    };
    return jsonEncode(data);
  }

  /// Import data from JSON
  Future<int> importData(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final entries = (data['entries'] as List)
          .map((e) => VaultEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      int imported = 0;
      for (final entry in entries) {
        // Check for duplicates by ID
        final existing = _vaultBox.values.where((e) => e.id == entry.id);
        if (existing.isEmpty) {
          await _vaultBox.add(entry);
          imported++;
        }
      }
      return imported;
    } catch (e) {
      return -1;
    }
  }

  /// Import with master config (full restore)
  Future<bool> importFullBackup(String jsonString, String masterPassword) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Restore config
      if (data['config'] != null) {
        final config =
            MasterConfig.fromJson(data['config'] as Map<String, dynamic>);

        // Verify master password against imported config
        final hash = CryptoService.hashPassword(masterPassword, config.salt);
        if (hash != config.passwordHash) return false;

        await _configBox.clear();
        await _configBox.add(config);

        _currentKey = CryptoService.deriveKey(masterPassword, config.salt);
        _currentIV = config.iv;
      }

      // Restore entries
      if (data['entries'] != null) {
        await _vaultBox.clear();
        final entries = (data['entries'] as List)
            .map((e) => VaultEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        for (final entry in entries) {
          await _vaultBox.add(entry);
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Import full backup without verifying password first.
  /// Used on fresh install - replaces everything.
  /// User must login with the backup's master password afterwards.
  Future<bool> importFullBackupWithoutPassword(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate the backup has required data
      if (data['config'] == null) return false;

      // Restore config (master password hash, security questions, etc.)
      final config =
          MasterConfig.fromJson(data['config'] as Map<String, dynamic>);
      await _configBox.clear();
      await _configBox.add(config);

      // Restore entries (replace all)
      if (data['entries'] != null) {
        await _vaultBox.clear();
        final entries = (data['entries'] as List)
            .map((e) => VaultEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        for (final entry in entries) {
          await _vaultBox.add(entry);
        }
      }

      // Don't unlock - user must login with the backup's password
      _currentKey = null;
      _currentIV = null;

      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Biometric (Hardware-backed Secure Storage) ─────────

  static const _secureStorage = FlutterSecureStorage();
  static const _biometricKeyName = 'oneshield_biometric_vault_key';

  /// Toggle biometric setting
  /// When enabling, stores the master key in Android Keystore / iOS Keychain
  /// (hardware-backed, cannot be extracted even with root access)
  Future<void> setBiometric(bool enabled) async {
    final config = masterConfig;
    if (config == null) return;

    if (enabled && _currentKey != null) {
      // Store master key in hardware-backed secure storage
      await _secureStorage.write(
        key: _biometricKeyName,
        value: base64Encode(_currentKey!),
      );
      config.biometricEnabled = true;
    } else {
      // Remove key from secure storage
      await _secureStorage.delete(key: _biometricKeyName);
      config.biometricEnabled = false;
    }
    await config.save();
  }

  /// Unlock vault using biometric (reads key from secure storage)
  bool unlockWithBiometric() {
    // This is called synchronously but we need async secure storage read.
    // Use the async version instead.
    return false;
  }

  /// Async version of biometric unlock
  Future<bool> unlockWithBiometricAsync() async {
    final config = masterConfig;
    if (config == null) return false;
    if (!config.biometricEnabled) return false;

    try {
      final keyBase64 = await _secureStorage.read(key: _biometricKeyName);
      if (keyBase64 == null || keyBase64.isEmpty) return false;

      _currentKey = base64Decode(keyBase64);
      _currentIV = config.iv;

      config.lastLogin = DateTime.now();
      await config.save();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Autofill Credentials Sync ─────────────────────────

  /// Get all decrypted credentials for autofill service
  List<Map<String, String>> getAutofillCredentials() {
    if (!isUnlocked) return [];
    final entries = getAllEntries();
    final credentials = <Map<String, String>>[];

    for (final entry in entries) {
      if (entry.category != 'password') continue;
      final decrypted = decryptFields(entry);
      final url = decrypted['url'] ?? '';
      final username = decrypted['username'] ?? '';
      final password = decrypted['password'] ?? '';

      if (url.isEmpty && username.isEmpty) continue;

      credentials.add({
        'id': entry.id,
        'title': entry.title,
        'url': url,
        'username': username,
        'password': password,
      });
    }
    return credentials;
  }

  /// Get entry count
  int get entryCount => _vaultBox.length;
}

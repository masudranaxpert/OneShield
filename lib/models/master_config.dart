import 'package:hive/hive.dart';

class MasterConfig extends HiveObject {
  @HiveField(0)
  String passwordHash;

  @HiveField(1)
  String salt;

  @HiveField(2)
  String iv;

  @HiveField(3)
  List<SecurityQuestion> securityQuestions;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime lastLogin;

  @HiveField(6)
  bool biometricEnabled;

  @HiveField(7)
  String? encryptedMasterKey;

  @HiveField(8)
  int recoveryAttemptsToday;

  @HiveField(9)
  String? lastRecoveryDate; // ISO date string YYYY-MM-DD

  @HiveField(10)
  String? biometricEncryptedKey; // Encrypted vault key for biometric unlock

  @HiveField(11)
  String? biometricSalt; // Salt used for biometric key derivation

  MasterConfig({
    required this.passwordHash,
    required this.salt,
    required this.iv,
    required this.securityQuestions,
    required this.createdAt,
    required this.lastLogin,
    this.biometricEnabled = false,
    this.encryptedMasterKey,
    this.recoveryAttemptsToday = 0,
    this.lastRecoveryDate,
    this.biometricEncryptedKey,
    this.biometricSalt,
  });

  Map<String, dynamic> toJson() => {
        'passwordHash': passwordHash,
        'salt': salt,
        'iv': iv,
        'securityQuestions': securityQuestions.map((q) => q.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'lastLogin': lastLogin.toIso8601String(),
        'biometricEnabled': biometricEnabled,
        'encryptedMasterKey': encryptedMasterKey,
        'recoveryAttemptsToday': recoveryAttemptsToday,
        'lastRecoveryDate': lastRecoveryDate,
        'biometricEncryptedKey': biometricEncryptedKey,
        'biometricSalt': biometricSalt,
      };

  factory MasterConfig.fromJson(Map<String, dynamic> json) => MasterConfig(
        passwordHash: json['passwordHash'],
        salt: json['salt'],
        iv: json['iv'],
        securityQuestions: (json['securityQuestions'] as List)
            .map((q) => SecurityQuestion.fromJson(q))
            .toList(),
        createdAt: DateTime.parse(json['createdAt']),
        lastLogin: DateTime.parse(json['lastLogin']),
        biometricEnabled: json['biometricEnabled'] ?? false,
        encryptedMasterKey: json['encryptedMasterKey'],
        recoveryAttemptsToday: json['recoveryAttemptsToday'] ?? 0,
        lastRecoveryDate: json['lastRecoveryDate'],
        biometricEncryptedKey: json['biometricEncryptedKey'],
        biometricSalt: json['biometricSalt'],
      );
}

class SecurityQuestion {
  @HiveField(0)
  String question;

  @HiveField(1)
  String answerHash;

  SecurityQuestion({
    required this.question,
    required this.answerHash,
  });

  Map<String, dynamic> toJson() => {
        'question': question,
        'answerHash': answerHash,
      };

  factory SecurityQuestion.fromJson(Map<String, dynamic> json) =>
      SecurityQuestion(
        question: json['question'],
        answerHash: json['answerHash'],
      );
}

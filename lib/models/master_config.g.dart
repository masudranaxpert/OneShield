import 'package:hive/hive.dart';
import 'master_config.dart';

class MasterConfigAdapter extends TypeAdapter<MasterConfig> {
  @override
  final int typeId = 1;

  @override
  MasterConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MasterConfig(
      passwordHash: fields[0] as String,
      salt: fields[1] as String,
      iv: fields[2] as String,
      securityQuestions:
          (fields[3] as List).cast<SecurityQuestion>(),
      createdAt: fields[4] as DateTime,
      lastLogin: fields[5] as DateTime,
      biometricEnabled: fields[6] as bool? ?? false,
      encryptedMasterKey: fields[7] as String?,
      recoveryAttemptsToday: fields[8] as int? ?? 0,
      lastRecoveryDate: fields[9] as String?,
      biometricEncryptedKey: fields[10] as String?,
      biometricSalt: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MasterConfig obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.passwordHash)
      ..writeByte(1)
      ..write(obj.salt)
      ..writeByte(2)
      ..write(obj.iv)
      ..writeByte(3)
      ..write(obj.securityQuestions)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.lastLogin)
      ..writeByte(6)
      ..write(obj.biometricEnabled)
      ..writeByte(7)
      ..write(obj.encryptedMasterKey)
      ..writeByte(8)
      ..write(obj.recoveryAttemptsToday)
      ..writeByte(9)
      ..write(obj.lastRecoveryDate)
      ..writeByte(10)
      ..write(obj.biometricEncryptedKey)
      ..writeByte(11)
      ..write(obj.biometricSalt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MasterConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SecurityQuestionAdapter extends TypeAdapter<SecurityQuestion> {
  @override
  final int typeId = 2;

  @override
  SecurityQuestion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SecurityQuestion(
      question: fields[0] as String,
      answerHash: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SecurityQuestion obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.question)
      ..writeByte(1)
      ..write(obj.answerHash);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecurityQuestionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

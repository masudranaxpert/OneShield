import 'package:hive/hive.dart';
import 'backup_config.dart';

class BackupConfigAdapter extends TypeAdapter<BackupConfig> {
  @override
  final int typeId = 3;

  @override
  BackupConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BackupConfig(
      refreshToken: fields[0] as String?,
      accessToken: fields[1] as String?,
      tokenExpiry: fields[2] as DateTime?,
      backupTime: fields[3] as String? ?? '02:00',
      autoBackupEnabled: fields[4] as bool? ?? false,
      lastBackup: fields[5] as DateTime?,
      driveFolder: fields[6] as String?,
      clientId: fields[7] as String? ?? '202264815644.apps.googleusercontent.com',
      clientSecret: fields[8] as String? ?? 'X4Z3ca8xfWDb1Voo-F9a7ZxJ',
      userEmail: fields[9] as String?,
      userName: fields[10] as String?,
      storageUsed: fields[11] as int?,
      storageLimit: fields[12] as int?,
      localBackupPath: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BackupConfig obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.refreshToken)
      ..writeByte(1)
      ..write(obj.accessToken)
      ..writeByte(2)
      ..write(obj.tokenExpiry)
      ..writeByte(3)
      ..write(obj.backupTime)
      ..writeByte(4)
      ..write(obj.autoBackupEnabled)
      ..writeByte(5)
      ..write(obj.lastBackup)
      ..writeByte(6)
      ..write(obj.driveFolder)
      ..writeByte(7)
      ..write(obj.clientId)
      ..writeByte(8)
      ..write(obj.clientSecret)
      ..writeByte(9)
      ..write(obj.userEmail)
      ..writeByte(10)
      ..write(obj.userName)
      ..writeByte(11)
      ..write(obj.storageUsed)
      ..writeByte(12)
      ..write(obj.storageLimit)
      ..writeByte(13)
      ..write(obj.localBackupPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

import 'package:hive/hive.dart';
import 'vault_entry.dart';

class VaultEntryAdapter extends TypeAdapter<VaultEntry> {
  @override
  final int typeId = 0;

  @override
  VaultEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VaultEntry(
      id: fields[0] as String,
      title: fields[1] as String,
      category: fields[2] as String,
      fields: Map<String, String>.from(fields[3] as Map),
      iconName: fields[4] as String?,
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
      isFavorite: fields[7] as bool? ?? false,
      tags: (fields[8] as List?)?.cast<String>() ?? [],
    );
  }

  @override
  void write(BinaryWriter writer, VaultEntry obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.fields)
      ..writeByte(4)
      ..write(obj.iconName)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.isFavorite)
      ..writeByte(8)
      ..write(obj.tags);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

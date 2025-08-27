import 'package:hive/hive.dart';
import '../../../models/ledger.dart';
import '../hive_config.dart';

class LedgerAdapter extends TypeAdapter<Ledger> {
  @override
  final int typeId = HiveConfig.ledgerTypeId;

  @override
  Ledger read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Ledger(
      id: fields[0] as String?,
      name: fields[1] as String,
      type: LedgerType.fromString(fields[3] as String? ?? 'personal'),
      description: fields[2] as String?,
      currency: fields[4] as String,
      isDefault: fields[7] as bool,
      createdAt: fields[12] as DateTime?,
      updatedAt: fields[13] as DateTime?,
      settings: fields[11] as Map<String, dynamic>?,
      memberIds: fields[15] != null ? (fields[15] as List).cast<String>() : null,
      ownerId: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Ledger obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.type.value)
      ..writeByte(4)
      ..write(obj.currency)
      ..writeByte(7)
      ..write(obj.isDefault)
      ..writeByte(11)
      ..write(obj.settings)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt)
      ..writeByte(15)
      ..write(obj.memberIds)
      ..writeByte(16)
      ..write(obj.ownerId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LedgerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
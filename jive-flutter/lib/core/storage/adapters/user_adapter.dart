import 'package:hive/hive.dart';
import '../../../models/user.dart';
import '../hive_config.dart';

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = HiveConfig.userTypeId;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return User(
      id: fields[0] as String?,
      name: fields[1] as String,
      email: fields[2] as String,
      phone: fields[3] as String?,
      avatar: fields[4] as String?,
      emailVerified: fields[5] as bool,
      phoneVerified: fields[6] as bool,
      role: UserRole.fromString(fields[7] as String?),
      createdAt: fields[8] as DateTime?,
      updatedAt: fields[9] as DateTime?,
      preferences: fields[10] as Map<String, dynamic>?,
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.avatar)
      ..writeByte(5)
      ..write(obj.emailVerified)
      ..writeByte(6)
      ..write(obj.phoneVerified)
      ..writeByte(7)
      ..write(obj.role.value)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.preferences);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
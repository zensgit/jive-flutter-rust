import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:jive_money/models/account.dart';
import 'package:jive_money/core/storage/hive_config.dart';

class AccountAdapter extends TypeAdapter<Account> {
  @override
  final int typeId = HiveConfig.accountTypeId;

  @override
  Account read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Account(
      id: fields[0] as String?,
      name: fields[1] as String,
      type: AccountType.fromString(fields[2] as String?),
      balance: fields[3] as double,
      currency: fields[4] as String,
      accountNumber: fields[5] as String?,
      description: fields[6] as String?,
      color: fields[7] != null ? Color(fields[7] as int) : null,
      isDefault: fields[8] as bool,
      excludeFromStats: fields[9] as bool,
      isArchived: fields[10] as bool,
      ledgerId: fields[11] as String?,
      groupId: fields[12] as String?,
      sortOrder: fields[13] as int?,
      createdAt: fields[14] as DateTime?,
      updatedAt: fields[15] as DateTime?,
      lastTransactionDate: fields[16] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Account obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type.value)
      ..writeByte(3)
      ..write(obj.balance)
      ..writeByte(4)
      ..write(obj.currency)
      ..writeByte(5)
      ..write(obj.accountNumber)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.color?.toARGB32())
      ..writeByte(8)
      ..write(obj.isDefault)
      ..writeByte(9)
      ..write(obj.excludeFromStats)
      ..writeByte(10)
      ..write(obj.isArchived)
      ..writeByte(11)
      ..write(obj.ledgerId)
      ..writeByte(12)
      ..write(obj.groupId)
      ..writeByte(13)
      ..write(obj.sortOrder)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.updatedAt)
      ..writeByte(16)
      ..write(obj.lastTransactionDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AccountGroupAdapter extends TypeAdapter<AccountGroup> {
  @override
  final int typeId = HiveConfig.accountGroupTypeId;

  @override
  AccountGroup read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AccountGroup(
      id: fields[0] as String?,
      name: fields[1] as String,
      description: fields[2] as String?,
      color: fields[3] != null ? Color(fields[3] as int) : null,
      // 使用常量替代运行时构造 IconData，兼容 web tree-shake-icons
      icon: fields[4] != null ? Icons.folder : null,
      sortOrder: fields[5] as int,
      accountIds: (fields[6] as List).cast<String>(),
      createdAt: fields[7] as DateTime?,
      updatedAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AccountGroup obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.color?.toARGB32())
      ..writeByte(4)
      ..write(obj.icon?.codePoint)
      ..writeByte(5)
      ..write(obj.sortOrder)
      ..writeByte(6)
      ..write(obj.accountIds)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountGroupAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

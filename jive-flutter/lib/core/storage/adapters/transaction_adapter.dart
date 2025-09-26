import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:jive_money/models/transaction.dart';
import 'package:jive_money/core/storage/hive_config.dart';

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = HiveConfig.transactionTypeId;

  @override
  Transaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transaction(
      id: fields[0] as String?,
      type: TransactionType.fromString(fields[1] as String?),
      amount: fields[2] as double,
      description: fields[3] as String,
      note: fields[4] as String?,
      category: fields[5] as String?,
      date: fields[6] as DateTime,
      accountId: fields[7] as String?,
      toAccountId: fields[8] as String?,
      ledgerId: fields[9] as String?,
      payee: fields[10] as String?,
      tags: fields[11] != null ? (fields[11] as List).cast<String>() : null,
      attachments: fields[12] != null
          ? (fields[12] as List).cast<TransactionAttachment>()
          : null,
      isRecurring: fields[13] as bool,
      recurringId: fields[14] as String?,
      isPending: fields[15] as bool,
      isReconciled: fields[16] as bool,
      createdAt: fields[17] as DateTime?,
      updatedAt: fields[18] as DateTime?,
      metadata: fields[19] as Map<String, dynamic>?,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type.value)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.note)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.accountId)
      ..writeByte(8)
      ..write(obj.toAccountId)
      ..writeByte(9)
      ..write(obj.ledgerId)
      ..writeByte(10)
      ..write(obj.payee)
      ..writeByte(11)
      ..write(obj.tags)
      ..writeByte(12)
      ..write(obj.attachments)
      ..writeByte(13)
      ..write(obj.isRecurring)
      ..writeByte(14)
      ..write(obj.recurringId)
      ..writeByte(15)
      ..write(obj.isPending)
      ..writeByte(16)
      ..write(obj.isReconciled)
      ..writeByte(17)
      ..write(obj.createdAt)
      ..writeByte(18)
      ..write(obj.updatedAt)
      ..writeByte(19)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TransactionAttachmentAdapter extends TypeAdapter<TransactionAttachment> {
  @override
  final int typeId = HiveConfig.attachmentTypeId;

  @override
  TransactionAttachment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionAttachment(
      id: fields[0] as String?,
      fileName: fields[1] as String,
      fileType: fields[2] as String,
      fileUrl: fields[3] as String?,
      fileSize: fields[4] as int?,
      uploadedAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionAttachment obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fileName)
      ..writeByte(2)
      ..write(obj.fileType)
      ..writeByte(3)
      ..write(obj.fileUrl)
      ..writeByte(4)
      ..write(obj.fileSize)
      ..writeByte(5)
      ..write(obj.uploadedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionAttachmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TransactionCategoryAdapter extends TypeAdapter<TransactionCategory> {
  @override
  final int typeId = HiveConfig.categoryTypeId;

  @override
  TransactionCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionCategory(
      id: fields[0] as String?,
      name: fields[1] as String,
      parentId: fields[2] as String?,
      // 避免运行时构造 IconData，改用常量
      icon: Icons.category,
      color: Color(fields[4] as int),
      type: TransactionType.fromString(fields[5] as String?),
      sortOrder: fields[6] as int,
      isSystem: fields[7] as bool,
      createdAt: fields[8] as DateTime?,
      updatedAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionCategory obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.parentId)
      ..writeByte(3)
      ..write(obj.icon.codePoint)
      ..writeByte(4)
      ..write(obj.color.toARGB32())
      ..writeByte(5)
      ..write(obj.type.value)
      ..writeByte(6)
      ..write(obj.sortOrder)
      ..writeByte(7)
      ..write(obj.isSystem)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ScheduledTransactionAdapter extends TypeAdapter<ScheduledTransaction> {
  @override
  final int typeId = HiveConfig.scheduledTransactionTypeId;

  @override
  ScheduledTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScheduledTransaction(
      id: fields[0] as String?,
      template: fields[1] as Transaction,
      period: RecurrencePeriod.fromString(fields[2] as String?),
      interval: fields[3] as int,
      startDate: fields[4] as DateTime,
      endDate: fields[5] as DateTime?,
      nextRunDate: fields[6] as DateTime?,
      occurrences: fields[7] as int?,
      executedCount: fields[8] as int,
      isActive: fields[9] as bool,
      autoConfirm: fields[10] as bool,
      createdAt: fields[11] as DateTime?,
      updatedAt: fields[12] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduledTransaction obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.template)
      ..writeByte(2)
      ..write(obj.period.value)
      ..writeByte(3)
      ..write(obj.interval)
      ..writeByte(4)
      ..write(obj.startDate)
      ..writeByte(5)
      ..write(obj.endDate)
      ..writeByte(6)
      ..write(obj.nextRunDate)
      ..writeByte(7)
      ..write(obj.occurrences)
      ..writeByte(8)
      ..write(obj.executedCount)
      ..writeByte(9)
      ..write(obj.isActive)
      ..writeByte(10)
      ..write(obj.autoConfirm)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduledTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

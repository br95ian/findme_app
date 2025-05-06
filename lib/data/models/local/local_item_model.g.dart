// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalItemModelAdapter extends TypeAdapter<LocalItemModel> {
  @override
  final int typeId = 0;

  @override
  LocalItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalItemModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      userName: fields[2] as String,
      userContact: fields[3] as String,
      title: fields[4] as String,
      description: fields[5] as String,
      category: fields[6] as String,
      type: fields[7] as LocalItemType,
      imagePaths: (fields[8] as List).cast<String>(),
      latitude: fields[9] as double,
      longitude: fields[10] as double,
      locationName: fields[11] as String,
      date: fields[12] as DateTime,
      createdAt: fields[13] as DateTime,
      updatedAt: fields[14] as DateTime,
      isUploaded: fields[15] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LocalItemModel obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.userName)
      ..writeByte(3)
      ..write(obj.userContact)
      ..writeByte(4)
      ..write(obj.title)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.type)
      ..writeByte(8)
      ..write(obj.imagePaths)
      ..writeByte(9)
      ..write(obj.latitude)
      ..writeByte(10)
      ..write(obj.longitude)
      ..writeByte(11)
      ..write(obj.locationName)
      ..writeByte(12)
      ..write(obj.date)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.updatedAt)
      ..writeByte(15)
      ..write(obj.isUploaded);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LocalItemTypeAdapter extends TypeAdapter<LocalItemType> {
  @override
  final int typeId = 1;

  @override
  LocalItemType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return LocalItemType.lost;
      case 1:
        return LocalItemType.found;
      default:
        return LocalItemType.lost;
    }
  }

  @override
  void write(BinaryWriter writer, LocalItemType obj) {
    switch (obj) {
      case LocalItemType.lost:
        writer.writeByte(0);
        break;
      case LocalItemType.found:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalItemTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

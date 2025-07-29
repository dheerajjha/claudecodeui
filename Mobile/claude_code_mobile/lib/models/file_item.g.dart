// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FileItem _$FileItemFromJson(Map<String, dynamic> json) => FileItem(
      name: json['name'] as String,
      path: json['path'] as String,
      type: json['type'] as String,
      size: (json['size'] as num?)?.toInt(),
      modified: json['modified'] as String?,
      children: (json['children'] as List<dynamic>?)
          ?.map((e) => FileItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      isExpanded: json['isExpanded'] as bool?,
    );

Map<String, dynamic> _$FileItemToJson(FileItem instance) => <String, dynamic>{
      'name': instance.name,
      'path': instance.path,
      'type': instance.type,
      'size': instance.size,
      'modified': instance.modified,
      'children': instance.children,
      'isExpanded': instance.isExpanded,
    };

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Session _$SessionFromJson(Map<String, dynamic> json) => Session(
      id: json['id'] as String,
      title: json['title'] as String?,
      projectName: json['projectName'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      messageCount: (json['messageCount'] as num?)?.toInt(),
    );

Map<String, dynamic> _$SessionToJson(Session instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'projectName': instance.projectName,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'messageCount': instance.messageCount,
    };

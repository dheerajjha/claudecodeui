// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Project _$ProjectFromJson(Map<String, dynamic> json) => Project(
      name: json['name'] as String,
      displayName: json['displayName'] as String?,
      fullPath: json['fullPath'] as String,
      path: json['path'] as String,
      sessionMeta: json['sessionMeta'] == null
          ? null
          : SessionMeta.fromJson(json['sessionMeta'] as Map<String, dynamic>),
      sessions: (json['sessions'] as List<dynamic>?)
          ?.map((e) => Session.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ProjectToJson(Project instance) => <String, dynamic>{
      'name': instance.name,
      'displayName': instance.displayName,
      'fullPath': instance.fullPath,
      'path': instance.path,
      'sessionMeta': instance.sessionMeta,
      'sessions': instance.sessions,
    };

SessionMeta _$SessionMetaFromJson(Map<String, dynamic> json) => SessionMeta(
      total: (json['total'] as num).toInt(),
      lastUpdated: json['lastUpdated'] as String?,
    );

Map<String, dynamic> _$SessionMetaToJson(SessionMeta instance) =>
    <String, dynamic>{
      'total': instance.total,
      'lastUpdated': instance.lastUpdated,
    };

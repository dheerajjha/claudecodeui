import 'package:json_annotation/json_annotation.dart';
import 'session.dart';

part 'project.g.dart';

@JsonSerializable()
class Project {
  final String name;
  final String? displayName;
  final String fullPath;
  final String path;
  final SessionMeta? sessionMeta;
  final List<Session>? sessions;

  const Project({
    required this.name,
    this.displayName,
    required this.fullPath,
    required this.path,
    this.sessionMeta,
    this.sessions,
  });

  factory Project.fromJson(Map<String, dynamic> json) =>
      _$ProjectFromJson(json);
  Map<String, dynamic> toJson() => _$ProjectToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          fullPath == other.fullPath;

  @override
  int get hashCode => name.hashCode ^ fullPath.hashCode;

  Project copyWith({
    String? name,
    String? displayName,
    String? fullPath,
    String? path,
    SessionMeta? sessionMeta,
    List<Session>? sessions,
  }) {
    return Project(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      fullPath: fullPath ?? this.fullPath,
      path: path ?? this.path,
      sessionMeta: sessionMeta ?? this.sessionMeta,
      sessions: sessions ?? this.sessions,
    );
  }
}

@JsonSerializable()
class SessionMeta {
  final int total;
  final String? lastUpdated;

  const SessionMeta({required this.total, this.lastUpdated});

  factory SessionMeta.fromJson(Map<String, dynamic> json) =>
      _$SessionMetaFromJson(json);
  Map<String, dynamic> toJson() => _$SessionMetaToJson(this);
}

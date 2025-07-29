import 'package:json_annotation/json_annotation.dart';

part 'file_item.g.dart';

@JsonSerializable()
class FileItem {
  final String name;
  final String path;
  final String type; // 'file' or 'directory'
  final int? size;
  final String? modified;
  final List<FileItem>? children;
  final bool? isExpanded;

  const FileItem({
    required this.name,
    required this.path,
    required this.type,
    this.size,
    this.modified,
    this.children,
    this.isExpanded,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) =>
      _$FileItemFromJson(json);
  Map<String, dynamic> toJson() => _$FileItemToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileItem &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;

  FileItem copyWith({
    String? name,
    String? path,
    String? type,
    int? size,
    String? modified,
    List<FileItem>? children,
    bool? isExpanded,
  }) {
    return FileItem(
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      size: size ?? this.size,
      modified: modified ?? this.modified,
      children: children ?? this.children,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  bool get isDirectory => type == 'directory';
  bool get isFile => type == 'file';
  bool get hasChildren => children != null && children!.isNotEmpty;
}

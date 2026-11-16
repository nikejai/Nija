import 'package:flutter/foundation.dart';

typedef VaultFolderCreateCallback = Future<VaultFolder?> Function(
  String name, {
  String? parentId,
  String? color,
});

@immutable
class VaultFolder {
  const VaultFolder({
    required this.id,
    required this.name,
    this.parentId,
    this.color,
    this.icon,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const <String>[],
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String name;
  final String? parentId;
  final String? color;
  final String? icon;
  final String createdAt;
  final String updatedAt;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  bool get isRoot => parentId == null || parentId!.trim().isEmpty;

  VaultFolder copyWith({
    String? id,
    String? name,
    String? parentId,
    bool clearParent = false,
    String? color,
    String? icon,
    String? createdAt,
    String? updatedAt,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return VaultFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: clearParent ? null : (parentId ?? this.parentId),
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }

  factory VaultFolder.fromJson(Map<String, dynamic> json) {
    return VaultFolder(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled Folder',
      parentId: (json['parentId'] == null || json['parentId'].toString().trim().isEmpty)
          ? null
          : json['parentId'].toString(),
      color: json['color']?.toString(),
      icon: json['icon']?.toString(),
      createdAt: json['createdAt']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      updatedAt: json['updatedAt']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => entry.toString())
          .toList(),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    if (parentId != null && parentId!.trim().isNotEmpty) 'parentId': parentId,
    if (color != null && color!.trim().isNotEmpty) 'color': color,
    if (icon != null && icon!.trim().isNotEmpty) 'icon': icon,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'tags': tags,
    'metadata': metadata,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultFolder &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          parentId == other.parentId &&
          color == other.color &&
          icon == other.icon &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          listEquals(tags, other.tags) &&
          mapEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    parentId,
    color,
    icon,
    createdAt,
    updatedAt,
    Object.hashAll(tags),
    Object.hashAll(metadata.entries),
  );
}

class VaultEntryFieldData {
  const VaultEntryFieldData({
    required this.label,
    required this.value,
    required this.sensitive,
  });

  final String label;
  final String value;
  final bool sensitive;

  factory VaultEntryFieldData.fromJson(Map<String, dynamic> json) {
    return VaultEntryFieldData(
      label: json['label']?.toString() ?? 'Field',
      value: json['value']?.toString() ?? '',
      sensitive: json['sensitive'] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'label': label,
    'value': value,
    'sensitive': sensitive,
  };
}

class VaultItemData {
  const VaultItemData({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.pinned,
    required this.tags,
    required this.fields,
  });

  final String id;
  final String type;
  final String title;
  final String subtitle;
  final bool pinned;
  final List<String> tags;
  final List<VaultEntryFieldData> fields;

  factory VaultItemData.fromJson(Map<String, dynamic> json) {
    return VaultItemData(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Item',
      title: json['title']?.toString() ?? 'Untitled',
      subtitle: json['subtitle']?.toString() ?? '',
      pinned: json['pinned'] == true,
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => entry.toString())
          .toList(),
      fields: (json['fields'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (entry) => VaultEntryFieldData.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type,
    'title': title,
    'subtitle': subtitle,
    'pinned': pinned,
    'tags': tags,
    'fields': fields.map((field) => field.toJson()).toList(),
  };
}

class VaultNoteData {
  const VaultNoteData({
    required this.id,
    required this.title,
    required this.preview,
    required this.pinned,
    required this.tags,
    required this.delta,
  });

  final String id;
  final String title;
  final String preview;
  final bool pinned;
  final List<String> tags;
  final List<Map<String, dynamic>> delta;

  factory VaultNoteData.fromJson(Map<String, dynamic> json) {
    return VaultNoteData(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled note',
      preview: json['preview']?.toString() ?? '',
      pinned: json['pinned'] == true,
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => entry.toString())
          .toList(),
      delta: (json['delta'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'preview': preview,
    'pinned': pinned,
    'tags': tags,
    'delta': delta,
  };
}

class VaultCustomTypeDefinitionData {
  const VaultCustomTypeDefinitionData({
    required this.name,
    required this.iconKey,
    required this.fields,
  });

  final String name;
  final String iconKey;
  final List<Map<String, dynamic>> fields;

  factory VaultCustomTypeDefinitionData.fromJson(Map<String, dynamic> json) {
    return VaultCustomTypeDefinitionData(
      name: json['name']?.toString() ?? '',
      iconKey: json['iconKey']?.toString() ?? '',
      fields: (json['fields'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'iconKey': iconKey,
    'fields': fields,
  };
}

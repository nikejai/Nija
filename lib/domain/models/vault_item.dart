class VaultItem {
  const VaultItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.fields,
  });

  final String id;
  final String type;
  final String title;
  final String subtitle;
  final List<VaultField> fields;
}

class VaultField {
  const VaultField({
    required this.id,
    required this.label,
    required this.value,
    required this.sensitive,
  });

  final String id;
  final String label;
  final String value;
  final bool sensitive;
}

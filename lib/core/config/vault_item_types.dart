class VaultItemType {
  const VaultItemType({
    required this.id,
    required this.label,
    required this.icon,
    required this.supported,
  });

  final String id;
  final String label;
  final String icon;
  final bool supported;
}

class VaultItemTypes {
  VaultItemTypes._();

  static const login = VaultItemType(
    id: 'login',
    label: 'Login',
    icon: 'key',
    supported: true,
  );

  static const card = VaultItemType(
    id: 'card',
    label: 'Card',
    icon: 'card',
    supported: true,
  );

  static const identity = VaultItemType(
    id: 'identity',
    label: 'Identity',
    icon: 'user',
    supported: true,
  );

  static const secureNote = VaultItemType(
    id: 'secure_note',
    label: 'Secure Note',
    icon: 'note',
    supported: true,
  );

  static const supportedNow = <VaultItemType>[login, card, identity, secureNote];

  static const recommendedNext = <String>[
    'Password',
    'Bank Account',
    'Passport',
    'Driver License',
    'SSH Key',
    'API Key',
    'Wi-Fi Credential',
    'Server/Database Credential',
    'License Key',
    'Address Profile',
  ];
}

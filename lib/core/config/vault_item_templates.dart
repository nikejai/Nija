import 'package:flutter/services.dart';

class VaultFieldTemplate {
  const VaultFieldTemplate({
    required this.label,
    this.valueType = 'text',
    this.sensitive = false,
    this.keyboardType,
  });

  final String label;
  final String valueType;
  final bool sensitive;
  final TextInputType? keyboardType;
}

class VaultItemTemplate {
  const VaultItemTemplate({required this.type, required this.fields});

  final String type;
  final List<VaultFieldTemplate> fields;
}

class VaultItemTemplates {
  VaultItemTemplates._();

  static const builtIn = <VaultItemTemplate>[
    VaultItemTemplate(
      type: 'Login',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Username or email'),
        VaultFieldTemplate(label: 'Password', sensitive: true),
        VaultFieldTemplate(label: 'Website'),
        VaultFieldTemplate(label: 'Notes'),
      ],
    ),
    VaultItemTemplate(
      type: 'Card',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(
          label: 'Card number',
          sensitive: true,
          keyboardType: TextInputType.number,
        ),
        VaultFieldTemplate(label: 'Name on card'),
        VaultFieldTemplate(label: 'Expiry', sensitive: true),
        VaultFieldTemplate(
          label: 'CVV',
          sensitive: true,
          keyboardType: TextInputType.number,
        ),
        VaultFieldTemplate(label: 'Notes'),
      ],
    ),
    VaultItemTemplate(
      type: 'Identity',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Full name'),
        VaultFieldTemplate(label: 'Document number', sensitive: true),
        VaultFieldTemplate(label: 'Country'),
        VaultFieldTemplate(label: 'Expiry'),
      ],
    ),
    VaultItemTemplate(
      type: 'Password',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Password', sensitive: true),
        VaultFieldTemplate(label: 'Usage / App'),
        VaultFieldTemplate(label: 'Notes'),
      ],
    ),
    VaultItemTemplate(
      type: 'Bank Account',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Bank name'),
        VaultFieldTemplate(label: 'Account number', sensitive: true),
        VaultFieldTemplate(label: 'IFSC / Routing code', sensitive: true),
        VaultFieldTemplate(label: 'Account holder'),
      ],
    ),
    VaultItemTemplate(
      type: 'Passport',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Passport number', sensitive: true),
        VaultFieldTemplate(label: 'Country'),
        VaultFieldTemplate(label: 'Issue date'),
        VaultFieldTemplate(label: 'Expiry date'),
      ],
    ),
    VaultItemTemplate(
      type: 'Driver License',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'License number', sensitive: true),
        VaultFieldTemplate(label: 'State / Region'),
        VaultFieldTemplate(label: 'Expiry date'),
      ],
    ),
    VaultItemTemplate(
      type: 'SSH Key',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Public key'),
        VaultFieldTemplate(label: 'Private key', sensitive: true),
        VaultFieldTemplate(label: 'Passphrase', sensitive: true),
      ],
    ),
    VaultItemTemplate(
      type: 'API Key',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Service'),
        VaultFieldTemplate(label: 'API key', sensitive: true),
        VaultFieldTemplate(label: 'Secret', sensitive: true),
      ],
    ),
    VaultItemTemplate(
      type: 'Wi-Fi Credential',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'SSID'),
        VaultFieldTemplate(label: 'Password', sensitive: true),
        VaultFieldTemplate(label: 'Security type'),
      ],
    ),
    VaultItemTemplate(
      type: 'Server/Database Credential',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Host'),
        VaultFieldTemplate(label: 'Username'),
        VaultFieldTemplate(label: 'Password', sensitive: true),
        VaultFieldTemplate(label: 'Port', keyboardType: TextInputType.number),
      ],
    ),
    VaultItemTemplate(
      type: 'License Key',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Product'),
        VaultFieldTemplate(label: 'License key', sensitive: true),
      ],
    ),
    VaultItemTemplate(
      type: 'Address Profile',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Full name'),
        VaultFieldTemplate(label: 'Phone'),
        VaultFieldTemplate(label: 'Address line'),
        VaultFieldTemplate(label: 'City / State / ZIP'),
      ],
    ),
  ];
}

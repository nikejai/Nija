class VaultHomeDemoData {
  VaultHomeDemoData._();

  static const vaultName = 'Personal Vault';
  static const guardianId = 'owl';
  static const itemCount = 12;

  static const recoveryWords = <String>[
    'summit',
    'aster',
    'breeze',
    'forge',
    'lantern',
    'onyx',
    'circle',
    'maple',
  ];

  static const folders = <String>[
    'Personal',
    'Work',
    'Finance',
    'Travel',
  ];

  static const items = <Map<String, dynamic>>[
    {
      'id': 'demo-login-github',
      'type': 'Login',
      'title': 'GitHub',
      'subtitle': 'nitesh@example.com',
      'folder': 'Work',
      'updated': 'Today',
      'updatedAt': '2026-08-13T15:41:00Z',
      'pinned': true,
      'fields': [
        {'label': 'Username or email', 'value': 'nitesh@example.com'},
        {'label': 'Password', 'value': 'demo-secret', 'sensitive': true},
        {'label': 'Website', 'value': 'github.com'},
        {'label': 'Notes', 'value': 'Primary developer account'},
      ],
    },
    {
      'id': 'demo-identity-passport',
      'type': 'Identity',
      'title': 'Passport',
      'subtitle': 'India · expires 2031',
      'folder': 'Travel',
      'updated': 'Yesterday',
      'updatedAt': '2026-08-12T12:15:00Z',
      'pinned': true,
      'fields': [
        {'label': 'Full name', 'value': 'Nitesh Jain'},
        {'label': 'Passport number', 'value': 'P7X4-92K1', 'sensitive': true},
        {'label': 'Country', 'value': 'India'},
        {'label': 'Expiry date', 'value': '12 Aug 2031'},
      ],
    },
    {
      'id': 'demo-card-primary',
      'type': 'Card',
      'title': 'Primary Card',
      'subtitle': 'Visa · •••• 4821',
      'folder': 'Finance',
      'updated': 'Aug 10',
      'updatedAt': '2026-08-10T08:20:00Z',
      'fields': [
        {
          'label': 'Card number',
          'value': '4111 1111 1111 4821',
          'sensitive': true,
        },
        {'label': 'Name on card', 'value': 'Nitesh Jain'},
        {'label': 'Expiry', 'value': '08/29', 'sensitive': true},
      ],
    },
    {
      'id': 'demo-document-insurance',
      'type': 'Documents',
      'title': 'Health Insurance',
      'subtitle': 'Policy ending 2814',
      'folder': 'Personal',
      'updated': 'Aug 9',
      'updatedAt': '2026-08-09T09:30:00Z',
      'documentFileName': 'health-insurance.pdf',
      'documentExtension': 'pdf',
      'documentSizeBytes': 512000,
      'fields': [
        {'label': 'Provider', 'value': 'Nija Demo Insurance'},
        {'label': 'Policy number', 'value': '2814', 'sensitive': true},
        {'label': 'Notes', 'value': 'Annual policy PDF'},
      ],
    },
    {
      'id': 'demo-login-aws',
      'type': 'Login',
      'title': 'AWS',
      'subtitle': 'work@example.com',
      'folder': 'Work',
      'updated': 'Aug 8',
      'updatedAt': '2026-08-08T18:00:00Z',
      'fields': [
        {'label': 'Username or email', 'value': 'work@example.com'},
        {'label': 'Password', 'value': 'aws-demo', 'sensitive': true},
        {'label': 'Website', 'value': 'aws.amazon.com'},
      ],
    },
  ];

  static List<Map<String, dynamic>> cloneItems() {
    return items
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> cloneNotes() {
    return notes
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  static const notes = <Map<String, dynamic>>[
    {
      'id': 'demo-note-recovery',
      'title': 'Recovery Phrase',
      'preview': 'Private recovery record',
      'folder': 'Personal',
      'updated': 'Today',
      'updatedAt': '2026-08-13T14:10:00Z',
      'pinned': true,
      'tags': ['recovery', 'security'],
      'delta': [
        {
          'insert':
              'summit aster breeze forge lantern onyx circle maple\n',
        },
      ],
    },
  ];
}

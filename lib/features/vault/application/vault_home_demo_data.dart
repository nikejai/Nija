import '../../../domain/models/vault_folder.dart';

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

  static const folders = <String>['Personal', 'Work', 'Finance', 'Travel'];

  static final demoFolders = <VaultFolder>[
    const VaultFolder(
      id: 'demo-folder-personal',
      name: 'Personal',
      createdAt: '2026-08-01T10:00:00Z',
      updatedAt: '2026-08-01T10:00:00Z',
    ),
    const VaultFolder(
      id: 'demo-folder-health',
      name: 'Health & Insurance',
      parentId: 'demo-folder-personal',
      createdAt: '2026-08-02T11:00:00Z',
      updatedAt: '2026-08-02T11:00:00Z',
    ),
    const VaultFolder(
      id: 'demo-folder-work',
      name: 'Work',
      createdAt: '2026-08-01T10:00:00Z',
      updatedAt: '2026-08-01T10:00:00Z',
    ),
    const VaultFolder(
      id: 'demo-folder-projects',
      name: 'Projects & Infra',
      parentId: 'demo-folder-work',
      createdAt: '2026-08-03T12:00:00Z',
      updatedAt: '2026-08-03T12:00:00Z',
    ),
    const VaultFolder(
      id: 'demo-folder-finance',
      name: 'Finance',
      createdAt: '2026-08-01T10:00:00Z',
      updatedAt: '2026-08-01T10:00:00Z',
    ),
    const VaultFolder(
      id: 'demo-folder-tax',
      name: 'Tax 2026',
      parentId: 'demo-folder-finance',
      createdAt: '2026-08-04T13:00:00Z',
      updatedAt: '2026-08-04T13:00:00Z',
    ),
    const VaultFolder(
      id: 'demo-folder-travel',
      name: 'Travel',
      createdAt: '2026-08-01T10:00:00Z',
      updatedAt: '2026-08-01T10:00:00Z',
    ),
  ];

  static List<VaultFolder> cloneFolders() {
    return List<VaultFolder>.from(demoFolders);
  }

  static const items = <Map<String, dynamic>>[
    {
      'id': 'demo-login-github',
      'type': 'Login',
      'title': 'GitHub',
      'subtitle': 'nitesh@example.com',
      'folder': 'Work',
      'folderId': 'demo-folder-work',
      'updated': 'Today',
      'updatedAt': '2026-08-13T15:41:00Z',
      'pinned': true,
      'demo': true,
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
      'folderId': 'demo-folder-travel',
      'updated': 'Yesterday',
      'updatedAt': '2026-08-12T12:15:00Z',
      'pinned': true,
      'demo': true,
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
      'folderId': 'demo-folder-finance',
      'updated': 'Aug 10',
      'updatedAt': '2026-08-10T08:20:00Z',
      'demo': true,
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
      'subtitle': 'Policy ending 2814 · 512 KB',
      'folder': 'Personal',
      'folderId': 'demo-folder-health',
      'updated': 'Aug 9',
      'updatedAt': '2026-08-09T09:30:00Z',
      'documentFileName': 'health-insurance.pdf',
      'documentExtension': 'pdf',
      'documentSizeBytes': 512000,
      'size': 512000,
      'sizeBytes': 512000,
      'demo': true,
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
      'folderId': 'demo-folder-projects',
      'updated': 'Aug 8',
      'updatedAt': '2026-08-08T18:00:00Z',
      'demo': true,
      'fields': [
        {'label': 'Username or email', 'value': 'work@example.com'},
        {'label': 'Password', 'value': 'aws-demo', 'sensitive': true},
        {'label': 'Website', 'value': 'aws.amazon.com'},
      ],
    },
    {
      'id': 'demo-doc-tax',
      'type': 'Documents',
      'title': 'W-2 Wage & Tax Statement',
      'subtitle': 'Tax Year 2026 · 1.4 MB',
      'folder': 'Finance',
      'folderId': 'demo-folder-tax',
      'updated': 'Aug 5',
      'updatedAt': '2026-08-05T11:20:00Z',
      'documentFileName': 'w2_tax_2026.pdf',
      'documentExtension': 'pdf',
      'documentSizeBytes': 1420000,
      'size': 1420000,
      'sizeBytes': 1420000,
      'demo': true,
      'fields': [
        {'label': 'Employer', 'value': 'Acme Global'},
        {'label': 'Tax Year', 'value': '2026'},
      ],
    },
    {
      'id': 'demo-server-prod',
      'type': 'Server',
      'title': 'Production DB Cluster',
      'subtitle': 'db.internal.cloud:5432',
      'folder': 'Work',
      'folderId': 'demo-folder-projects',
      'updated': 'Aug 3',
      'updatedAt': '2026-08-03T16:45:00Z',
      'demo': true,
      'fields': [
        {'label': 'Host', 'value': 'db.internal.cloud'},
        {'label': 'Port', 'value': '5432'},
        {'label': 'Database', 'value': 'nija_prod'},
      ],
    },
    {
      'id': 'demo-wifi-home',
      'type': 'WiFi',
      'title': 'Home Mesh WiFi',
      'subtitle': 'Nija-Fiber-5G',
      'folder': 'Personal',
      'folderId': 'demo-folder-personal',
      'updated': 'Jul 28',
      'updatedAt': '2026-07-28T09:15:00Z',
      'demo': true,
      'fields': [
        {'label': 'Network SSID', 'value': 'Nija-Fiber-5G'},
        {'label': 'Password', 'value': 'SafeMesh#2026!', 'sensitive': true},
      ],
    },
    {
      'id': 'demo-flight-ticket',
      'type': 'Documents',
      'title': 'Flight Boarding Pass',
      'subtitle': 'SFO -> BLR · 380 KB',
      'folder': 'Travel',
      'folderId': 'demo-folder-travel',
      'updated': 'Jul 20',
      'updatedAt': '2026-07-20T14:30:00Z',
      'documentFileName': 'boarding_pass.pdf',
      'documentExtension': 'pdf',
      'documentSizeBytes': 389120,
      'size': 389120,
      'sizeBytes': 389120,
      'demo': true,
      'fields': [
        {'label': 'Airline', 'value': 'Airways'},
        {'label': 'Flight', 'value': 'AW-102'},
      ],
    },
    {
      'id': 'demo-general-seed',
      'type': 'Password',
      'title': 'Master Generator Seed',
      'subtitle': 'Default vault item',
      'folder': null,
      'folderId': null,
      'updated': 'Jul 15',
      'updatedAt': '2026-07-15T10:00:00Z',
      'demo': true,
      'fields': [
        {'label': 'Password', 'value': 'Tr0ub4dor&3', 'sensitive': true},
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
      'folderId': 'demo-folder-personal',
      'updated': 'Today',
      'updatedAt': '2026-08-13T14:10:00Z',
      'pinned': true,
      'demo': true,
      'tags': ['recovery', 'security'],
      'delta': [
        {'insert': 'summit aster breeze forge lantern onyx circle maple\n'},
      ],
    },
  ];
}

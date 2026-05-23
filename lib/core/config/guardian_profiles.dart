class GuardianProfile {
  const GuardianProfile({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.tagline,
    required this.detail,
    required this.memoryKb,
    required this.iterations,
    required this.parallelism,
    required this.cipher,
  });

  final String id;
  final String displayName;
  final String icon;
  final String tagline;
  final String detail;
  final int memoryKb;
  final int iterations;
  final int parallelism;
  final String cipher;
}

class GuardianProfiles {
  GuardianProfiles._();

  static const owl = GuardianProfile(
    id: 'owl_v1',
    displayName: 'Owl',
    icon: '🦉',
    tagline: 'Balanced everyday protection',
    detail: 'Recommended for most vaults.',
    memoryKb: 8192,
    iterations: 2,
    parallelism: 1,
    cipher: 'xchacha20-poly1305',
  );

  static const lion = GuardianProfile(
    id: 'lion_v1',
    displayName: 'Lion',
    icon: '🦁',
    tagline: 'Maximum protection',
    detail: 'For banking, identity, business, and high-value secrets.',
    memoryKb: 16384,
    iterations: 3,
    parallelism: 1,
    cipher: 'xchacha20-poly1305',
  );

  static const falcon = GuardianProfile(
    id: 'falcon_v1',
    displayName: 'Falcon',
    icon: '🦅',
    tagline: 'Fast daily unlock',
    detail: 'For lightweight vaults used many times daily.',
    memoryKb: 4096,
    iterations: 1,
    parallelism: 1,
    cipher: 'xchacha20-poly1305',
  );

  static const all = [owl, lion, falcon];
}

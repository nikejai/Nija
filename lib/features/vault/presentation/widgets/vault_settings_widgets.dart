part of '../vault_app_shell.dart';

String _formatAutoLockSeconds(int seconds) {
  if (seconds <= 0) return 'Off';
  if (seconds == 1) return '1 sec';
  if (seconds < 60) return '$seconds sec';
  if (seconds % 60 == 0) {
    final minutes = seconds ~/ 60;
    return minutes == 1 ? '60 sec' : '$seconds sec';
  }
  return '$seconds sec';
}

IconData _iconForSetting(String section) {
  if (section == AppStrings.settingsSecurity) return Icons.security_outlined;
  if (section == AppStrings.settingsVaultBackup) return Icons.backup_outlined;
  if (section == AppStrings.settingsBiometricUnlock) return Icons.fingerprint;
  if (section == AppStrings.settingsRecoveryPhrase) return Icons.key_outlined;
  if (section == AppStrings.settingsAutoLock) return Icons.lock_clock_outlined;
  if (section == AppStrings.settingsExportVault) {
    return Icons.file_upload_outlined;
  }
  if (section == AppStrings.settingsDangerZone) {
    return Icons.warning_amber_outlined;
  }
  return Icons.settings_outlined;
}

class _PasswordStrengthMeter extends StatelessWidget {
  const _PasswordStrengthMeter({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = _passwordStrengthScore(password);
    final label = _passwordStrengthLabel(score);
    final color = _passwordStrengthColor(theme, score);
    final guidance = VaultValidators.isStrongEnoughMasterPassword(password)
        ? 'Meets recommended minimum'
        : 'Use 10+ characters with letters and numbers';

    return Semantics(
      label: 'Password strength $label',
      child: Column(
        key: const ValueKey('master-password-strength-meter'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: score / 4,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                key: const ValueKey('master-password-strength-label'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            guidance,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RotateMasterPasswordDialog extends StatefulWidget {
  const _RotateMasterPasswordDialog();

  @override
  State<_RotateMasterPasswordDialog> createState() =>
      _RotateMasterPasswordDialogState();
}

class _RotateMasterPasswordDialogState
    extends State<_RotateMasterPasswordDialog> {
  final _currentController = TextEditingController();
  final _nextController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _nextController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _currentController.text.trim().isNotEmpty &&
        _nextController.text.trim().isNotEmpty &&
        _nextController.text == _confirmController.text;
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(
      context,
    ).pop((_currentController.text.trim(), _nextController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final nextPassword = _nextController.text.trim();
    final canSubmit = _canSubmit;
    return AlertDialog(
      title: const Text('Rotate master password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentController,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Current master password',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nextController,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'New master password',
              ),
            ),
            const SizedBox(height: 10),
            _PasswordStrengthMeter(password: nextPassword),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmController,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Confirm new master password',
                helperText: _confirmController.text.isEmpty || canSubmit
                    ? null
                    : 'Passwords do not match',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: canSubmit ? _submit : null,
          child: const Text('Rotate'),
        ),
      ],
    );
  }
}

int _passwordStrengthScore(String password) {
  if (password.isEmpty) return 0;
  var score = 0;
  if (password.length >= 10) score++;
  if (password.contains(RegExp(r'[A-Za-z]'))) score++;
  if (password.contains(RegExp(r'\d'))) score++;
  if (password.contains(RegExp(r'[^A-Za-z0-9]')) || password.length >= 16) {
    score++;
  }
  return score.clamp(1, 4);
}

String _passwordStrengthLabel(int score) {
  return switch (score) {
    0 => 'Not started',
    1 => 'Weak',
    2 => 'Fair',
    3 => 'Good',
    _ => 'Strong',
  };
}

Color _passwordStrengthColor(ThemeData theme, int score) {
  return switch (score) {
    0 => theme.colorScheme.outline,
    1 => theme.colorScheme.error,
    2 => const Color(0xFFB45309),
    3 => const Color(0xFF2563EB),
    _ => const Color(0xFF15803D),
  };
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.primary;
    final effectiveTitleColor = danger
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 78),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 0.6,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: effectiveIconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: effectiveTitleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (trailing != null)
                trailing!
              else ...[
                if (value != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoSectionData {
  const _InfoSectionData({required this.title, required this.body});

  final String title;
  final String body;
}

class _InfoDetailSheet extends StatefulWidget {
  const _InfoDetailSheet({
    required this.title,
    required this.icon,
    required this.sections,
  });

  final String title;
  final IconData icon;
  final List<_InfoSectionData> sections;

  @override
  State<_InfoDetailSheet> createState() => _InfoDetailSheetState();
}

class _InfoDetailSheetState extends State<_InfoDetailSheet> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  interactive: true,
                  child: ListView.separated(
                    controller: _scrollController,
                    shrinkWrap: true,
                    itemCount: widget.sections.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final section = widget.sections[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            section.body,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoLockSecondsSheet extends StatefulWidget {
  const _AutoLockSecondsSheet({required this.initialSeconds});

  final int initialSeconds;

  @override
  State<_AutoLockSecondsSheet> createState() => _AutoLockSecondsSheetState();
}

class _AutoLockSecondsSheetState extends State<_AutoLockSecondsSheet> {
  late double _seconds;

  @override
  void initState() {
    super.initState();
    _seconds = widget.initialSeconds.clamp(0, 3600).toDouble();
  }

  int get _roundedSeconds => _seconds.round();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Auto Lock',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_roundedSeconds),
                  child: const Text('Done'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _formatAutoLockSeconds(_roundedSeconds),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Slider(
              key: const ValueKey('auto-lock-seconds-slider'),
              value: _seconds,
              min: 0,
              max: 3600,
              divisions: 360,
              label: _formatAutoLockSeconds(_roundedSeconds),
              onChanged: (value) => setState(() => _seconds = value),
            ),
            Row(
              children: [
                Text(
                  'Off',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  '3600 sec',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Row(
        children: [
          for (final child in children) ...[
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  outlinedButtonTheme: OutlinedButtonThemeData(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ),
                child: child,
              ),
            ),
            if (child != children.last) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _RenameVaultDialog extends StatefulWidget {
  const _RenameVaultDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameVaultDialog> createState() => _RenameVaultDialogState();
}

class _RenameVaultDialogState extends State<_RenameVaultDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename vault'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: AppStrings.vaultName),
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (trimmed.isEmpty) return 'Enter a vault name';
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Rename')),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';

import '../../../app/theme/entry_typography.dart';
import '../../../core/config/guardian_profiles.dart';
import '../../../core/localization/app_strings.dart';
import 'onboarding_scaffold.dart';
import 'widgets/origami_guardian_icon.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({
    super.key,
    required this.vaultName,
    this.vaultId,
    required this.guardianProfile,
    required this.passwordController,
    this.pinEnabled = false,
    required this.biometricEnabled,
    required this.biometricUnlockLabel,
    required this.biometricUnlockIcon,
    this.showRecoveryAction = true,
    this.themeMode = ThemeMode.dark,
    this.onThemeModeChanged,
    required this.onBack,
    required this.onUnlock,
    this.onPinUnlock,
    required this.onBiometricUnlock,
    required this.onRecover,
    required this.onSelectDifferentVault,
    required this.onOpenEncryptedSecret,
    required this.onCreateVault,
  });

  final String vaultName;
  final String? vaultId;
  final GuardianProfile guardianProfile;
  final TextEditingController passwordController;
  final bool pinEnabled;
  final bool biometricEnabled;
  final String biometricUnlockLabel;
  final IconData biometricUnlockIcon;
  final bool showRecoveryAction;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final Future<void> Function() onBack;
  final Future<void> Function() onUnlock;
  final Future<void> Function()? onPinUnlock;
  final Future<void> Function() onBiometricUnlock;
  final Future<void> Function() onRecover;
  final Future<void> Function() onSelectDifferentVault;
  final Future<void> Function() onOpenEncryptedSecret;
  final Future<void> Function() onCreateVault;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  bool _obscurePassword = true;
  bool _autoPinAttempted = false;
  bool _autoBiometricAttempted = false;

  @override
  void initState() {
    super.initState();
    _schedulePreferredQuickUnlock();
  }

  @override
  void didUpdateWidget(covariant UnlockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.biometricEnabled &&
        !oldWidget.biometricEnabled &&
        !_autoBiometricAttempted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoBiometricAttempted) return;
        _autoBiometricAttempted = true;
        unawaited(widget.onBiometricUnlock());
      });
    }
    if (widget.pinEnabled &&
        !oldWidget.pinEnabled &&
        !widget.biometricEnabled &&
        !_autoPinAttempted) {
      _schedulePreferredQuickUnlock();
    }
  }

  void _schedulePreferredQuickUnlock() {
    if (widget.biometricEnabled && !_autoBiometricAttempted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoBiometricAttempted) return;
        _autoBiometricAttempted = true;
        unawaited(widget.onBiometricUnlock());
      });
      return;
    }
    if (widget.pinEnabled &&
        widget.onPinUnlock != null &&
        !widget.biometricEnabled &&
        !_autoPinAttempted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoPinAttempted) return;
        _autoPinAttempted = true;
        unawaited(widget.onPinUnlock!());
      });
    }
  }

  String _displayTitle() {
    final raw = widget.vaultName.trim();
    if (raw.isEmpty ||
        raw == 'vault.nija' ||
        raw == 'nija_vault.nija' ||
        raw == 'web_vault.nija' ||
        _isUuid(raw)) {
      return 'Personal Vault';
    }
    return raw;
  }

  String _truncatedId() {
    final rawId = (widget.vaultId ?? (_isUuid(widget.vaultName) ? widget.vaultName : '')).trim();
    final clean = rawId.endsWith('.nija') ? rawId.substring(0, rawId.length - 5) : rawId;
    if (clean.length > 8 && _isUuid(clean)) {
      return '${clean.substring(0, 4)}...${clean.substring(clean.length - 4)}';
    }
    return '';
  }

  static bool _isUuid(String value) {
    final clean = value.endsWith('.nija') ? value.substring(0, value.length - 5) : value;
    final parts = clean.split('-');
    return parts.length == 5 && clean.length == 36;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final protectedBy =
        'Protected by ${widget.guardianProfile.displayName} Guardian';

    return OnboardingScaffold(
      fullWidth: true,
      child: Column(
        key: const ValueKey('unlock-screen'),
        children: [
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('unlock-back'),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => unawaited(widget.onBack()),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    AppStrings.unlockVault,
                    textAlign: TextAlign.center,
                    style: EntryTypography.headerTitle(colorScheme.onSurface),
                  ),
                ),
                IconButton(
                  key: const ValueKey('unlock-theme-toggle'),
                  tooltip: AppStrings.changeTheme,
                  onPressed: widget.onThemeModeChanged == null
                      ? null
                      : () => widget.onThemeModeChanged!(
                          isDark ? ThemeMode.light : ThemeMode.dark,
                        ),
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 40),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 68,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.center,
                            child: OrigamiGuardianIcon(
                              guardianId: widget.guardianProfile.id,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _displayTitle(),
                            textAlign: TextAlign.center,
                            style: EntryTypography.unlockTitle(
                              colorScheme.onSurface,
                            ),
                          ),
                          if (_truncatedId().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _truncatedId(),
                              textAlign: TextAlign.center,
                              style: EntryTypography.technicalMonospace(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            protectedBy,
                            textAlign: TextAlign.center,
                            style: EntryTypography.unlockSubtitle(
                              colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.masterPassword.toUpperCase(),
                                  style: EntryTypography.fieldLabel(
                                    colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                TextField(
                                  key: const ValueKey('unlock-password-field'),
                                  controller: widget.passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _unlockIfReady(),
                                  decoration: InputDecoration(
                                    hintText: AppStrings.masterPassword,
                                    filled: true,
                                    fillColor: colorScheme.surface,
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      tooltip: _obscurePassword
                                          ? 'Show password'
                                          : 'Hide password',
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              key: const ValueKey('unlock-submit-button'),
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.onSurface,
                                foregroundColor: colorScheme.surface,
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: EntryTypography.restoreButton(
                                  colorScheme.surface,
                                ),
                              ),
                              onPressed: _unlockIfReady,
                              child: Text(AppStrings.unlock),
                            ),
                          ),
                          if (widget.pinEnabled &&
                              widget.onPinUnlock != null) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                key: const ValueKey('unlock-pin-button'),
                                onPressed: () =>
                                    unawaited(widget.onPinUnlock!()),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                                icon: const Icon(Icons.pin_outlined),
                                label: Text(AppStrings.unlockWithPin),
                              ),
                            ),
                          ],
                          if (widget.biometricEnabled) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                key: const ValueKey('unlock-biometric-button'),
                                onPressed: () =>
                                    unawaited(widget.onBiometricUnlock()),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                                icon: Icon(widget.biometricUnlockIcon),
                                label: Text(widget.biometricUnlockLabel),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          if (widget.showRecoveryAction)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: widget.onRecover,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant,
                                  ),
                                  textStyle: EntryTypography.restoreButton(
                                    colorScheme.onSurface,
                                  ),
                                ),
                                child: Text(AppStrings.webRecoverWithPhrase),
                              ),
                            ),
                          if (widget.showRecoveryAction)
                            const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: widget.onSelectDifferentVault,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: BorderSide(
                                  color: colorScheme.outlineVariant,
                                ),
                                textStyle: EntryTypography.restoreButton(
                                  colorScheme.onSurface,
                                ),
                              ),
                              child: Text(AppStrings.selectDifferentVault),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 2,
                            children: [
                              TextButton(
                                onPressed: widget.onOpenEncryptedSecret,
                                child: Text(AppStrings.openEncryptedSecret),
                              ),
                              TextButton(
                                onPressed: widget.onCreateVault,
                                child: Text(AppStrings.createVault),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Text(
                            AppStrings.webLocalYours,
                            textAlign: TextAlign.center,
                            style: EntryTypography.unlockFooter(
                              colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unlockIfReady() async {
    if (widget.passwordController.text.trim().isNotEmpty) {
      await widget.onUnlock();
    }
  }
}

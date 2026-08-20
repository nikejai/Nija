import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../app/theme/entry_typography.dart';
import '../../../../infrastructure/adapters/google_drive_vault_portability.dart';
import 'google_drive_sign_in_button/platform.dart' as gsi_button;

/// Web-only dialog: GIS [renderButton] for sign-in, then an explicit button
/// for Drive scope authorization.
class GoogleDriveWebSignInDialog extends StatefulWidget {
  const GoogleDriveWebSignInDialog({
    super.key,
    this.forceAccountChooser = true,
  });

  final bool forceAccountChooser;

  @override
  State<GoogleDriveWebSignInDialog> createState() =>
      _GoogleDriveWebSignInDialogState();
}

class _GoogleDriveWebSignInDialogState
    extends State<GoogleDriveWebSignInDialog> {
  final GoogleSignIn _googleSignIn = googleDriveSignInClient();
  StreamSubscription<GoogleSignInAccount?>? _userSubscription;
  GoogleSignInAccount? _authenticatedUser;
  var _authorizing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _userSubscription = _googleSignIn.onCurrentUserChanged.listen(
      _handleUserChanged,
    );
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (widget.forceAccountChooser) {
      await _resetSession();
    } else {
      await _tryCompleteIfAlreadyAuthorized();
    }
  }

  @override
  void dispose() {
    unawaited(_userSubscription?.cancel());
    super.dispose();
  }

  Future<void> _resetSession() async {
    const portability = GoogleDriveVaultPortability();
    portability.resetDriveAuthClient();
    await _googleSignIn.signOut();
    if (!mounted) return;
    setState(() {
      _authenticatedUser = null;
      _errorMessage = null;
    });
  }

  Future<void> _tryCompleteIfAlreadyAuthorized() async {
    if (!await _googleSignIn.canAccessScopes(googleDriveOAuthScopes)) return;
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _handleUserChanged(GoogleSignInAccount? account) {
    if (!mounted) return;
    setState(() {
      _authenticatedUser = account;
      if (account != null) {
        _errorMessage = null;
      }
    });
  }

  Future<void> _authorizeDriveAccess() async {
    if (_authorizing) return;
    setState(() {
      _authorizing = true;
      _errorMessage = null;
    });

    try {
      final granted = await _googleSignIn.requestScopes(googleDriveOAuthScopes);
      if (!mounted) return;
      if (granted) {
        const GoogleDriveVaultPortability().resetDriveAuthClient();
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _authorizing = false;
        _errorMessage =
            'Google Drive access was not granted. Allow Drive permissions and try again.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _authorizing = false;
        _errorMessage = 'Could not authorize Google Drive access. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final signedIn = _authenticatedUser;
    final stepOneComplete = signedIn != null;
    final canAuthorize = signedIn != null && !_authorizing;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: isDark ? 36 : 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Icon(
                          Icons.cloud_outlined,
                          size: 24,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connect Google Drive',
                              style: EntryTypography.pageHeading(
                                colorScheme.onSurface,
                              ).copyWith(fontSize: 22, letterSpacing: -0.3),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Link the Google account that stores your vault backup.',
                              style: EntryTypography.pageDescription(
                                colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: _authorizing
                            ? null
                            : () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'SETUP STEPS',
                        style: EntryTypography.sectionLabel(
                          colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _DriveSetupStep(
                        code: '01',
                        title: 'Sign in with Google',
                        subtitle: 'Choose the account that has your backup.',
                        complete: stepOneComplete,
                        active: !stepOneComplete,
                        child: signedIn == null
                            ? Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: gsi_button
                                      .buildGoogleDriveSignInButton(),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 10),
                      _DriveSetupStep(
                        code: '02',
                        title: 'Allow Drive access',
                        subtitle:
                            'Grant permission to find and restore backups.',
                        complete: false,
                        active: stepOneComplete,
                        child: signedIn == null
                            ? null
                            : Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _ConnectedAccountCard(account: signedIn),
                                    const SizedBox(height: 12),
                                    FilledButton.icon(
                                      onPressed: canAuthorize
                                          ? _authorizeDriveAccess
                                          : null,
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(44),
                                        backgroundColor: colorScheme.primary,
                                        foregroundColor: colorScheme.onPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        textStyle:
                                            EntryTypography.restoreButton(
                                              colorScheme.onPrimary,
                                            ),
                                      ),
                                      icon: _authorizing
                                          ? SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: colorScheme.onPrimary,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.cloud_done_outlined,
                                            ),
                                      label: Text(
                                        _authorizing
                                            ? 'Authorizing…'
                                            : 'Allow Google Drive access',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.center,
                                      child: TextButton(
                                        onPressed: _authorizing
                                            ? null
                                            : _resetSession,
                                        style: TextButton.styleFrom(
                                          textStyle:
                                              EntryTypography.restoreButton(
                                                colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                        child: const Text(
                                          'Use a different account',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer.withValues(
                              alpha: isDark ? 0.35 : 0.45,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colorScheme.error.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 18,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: EntryTypography.emptyStateBody(
                                    colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriveSetupStep extends StatelessWidget {
  const _DriveSetupStep({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.complete,
    required this.active,
    this.child,
  });

  final String code;
  final String title;
  final String subtitle;
  final bool complete;
  final bool active;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = active
        ? colorScheme.primary.withValues(alpha: 0.45)
        : colorScheme.outlineVariant;
    final backgroundColor = active
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.55)
        : colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  code,
                  style: EntryTypography.actionCode(
                    complete
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: EntryTypography.actionTitle(
                              colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (complete)
                          Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: EntryTypography.actionSubtitle(
                        colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ?child,
        ],
      ),
    );
  }
}

class _ConnectedAccountCard extends StatelessWidget {
  const _ConnectedAccountCard({required this.account});

  final GoogleSignInAccount account;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          GoogleUserCircleAvatar(identity: account),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.displayName ?? account.email,
                  style: EntryTypography.vaultCardTitle(colorScheme.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  account.email,
                  style: EntryTypography.vaultCardMeta(
                    colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

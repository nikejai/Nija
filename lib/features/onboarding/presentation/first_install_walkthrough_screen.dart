import 'package:flutter/material.dart';

import 'onboarding_scaffold.dart';

class FirstInstallWalkthroughScreen extends StatefulWidget {
  const FirstInstallWalkthroughScreen({
    super.key,
    required this.onSkip,
    required this.onFinish,
  });

  final Future<void> Function() onSkip;
  final Future<void> Function() onFinish;

  @override
  State<FirstInstallWalkthroughScreen> createState() =>
      _FirstInstallWalkthroughScreenState();
}

class _FirstInstallWalkthroughScreenState
    extends State<FirstInstallWalkthroughScreen> {
  final _pageController = PageController();
  int _pageIndex = 0;
  bool _submitting = false;

  static const _pages = <_WalkthroughPageData>[
    _WalkthroughPageData(
      icon: Icons.lock_outline,
      title: 'Create or open a vault',
      body:
          'Start with a new private vault or open one you already saved on this device.',
    ),
    _WalkthroughPageData(
      icon: Icons.key_outlined,
      title: 'Save your recovery phrase',
      body:
          'Your recovery phrase is the offline way back in if you forget the vault password.',
    ),
    _WalkthroughPageData(
      icon: Icons.fingerprint,
      title: 'Unlock safely',
      body:
          'Use your password first, then enable biometrics for faster unlocks on trusted devices.',
    ),
    _WalkthroughPageData(
      icon: Icons.inventory_2_outlined,
      title: 'Add items and documents',
      body:
          'Store passwords, notes, identities, documents, and attachments in encrypted vault data.',
    ),
    _WalkthroughPageData(
      icon: Icons.cloud_upload_outlined,
      title: 'Back up and recover',
      body:
          'Export encrypted vault backups, use cloud backup when available, and recover with your phrase when needed.',
    ),
  ];

  bool get _isLastPage => _pageIndex == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish(Future<void> Function() action) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _next() async {
    if (_isLastPage) {
      await _finish(widget.onFinish);
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return OnboardingScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('first-install-walkthrough-skip'),
                  onPressed: _submitting ? null : () => _finish(widget.onSkip),
                  child: const Text('Skip'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  key: const ValueKey('first-install-walkthrough-pages'),
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _pageIndex = index),
                  itemBuilder: (context, index) =>
                      _WalkthroughPage(data: _pages[index]),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _pageIndex ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == _pageIndex
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('first-install-walkthrough-next'),
                  onPressed: _submitting ? null : _next,
                  icon: Icon(
                    _isLastPage
                        ? Icons.check_circle_outline
                        : Icons.arrow_forward,
                  ),
                  label: Text(_isLastPage ? 'Get started' : 'Continue'),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Step ${_pageIndex + 1} of ${_pages.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalkthroughPage extends StatelessWidget {
  const _WalkthroughPage({required this.data});

  final _WalkthroughPageData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(data.icon, size: 42, color: colorScheme.primary),
          ),
          const SizedBox(height: 34),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(
              data.body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkthroughPageData {
  const _WalkthroughPageData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

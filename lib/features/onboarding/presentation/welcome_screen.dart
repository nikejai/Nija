import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import 'onboarding_scaffold.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onCreateVault,
    required this.onOpenExistingVault,
  });

  final VoidCallback onCreateVault;
  final VoidCallback onOpenExistingVault;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return OnboardingScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 64),
                  Text(
                    AppStrings.welcomeLabel,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.welcomeTitle,
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    AppStrings.welcomeDescription,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _TrustPoint(label: AppStrings.valueZeroKnowledge),
                  const SizedBox(height: 12),
                  _TrustPoint(label: AppStrings.valueLocalFirst),
                  const SizedBox(height: 12),
                  _TrustPoint(label: AppStrings.valuePortableFile),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onCreateVault,
                      child: Text(AppStrings.createVault),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onOpenExistingVault,
                      child: Text(AppStrings.openExistingVault),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustPoint extends StatelessWidget {
  const _TrustPoint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(Icons.check, size: 13, color: colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

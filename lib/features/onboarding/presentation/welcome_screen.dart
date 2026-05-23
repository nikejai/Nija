import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
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
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.lock_outline, color: Colors.white),
                  ),
                  const SizedBox(height: 64),
                  Text(AppStrings.welcomeLabel, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Text(AppStrings.welcomeTitle, style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 18),
                  Text(
                    AppStrings.welcomeDescription,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
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
                    child: ElevatedButton(onPressed: onCreateVault, child: Text(AppStrings.createVault)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(onPressed: onOpenExistingVault, child: Text(AppStrings.openExistingVault)),
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
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.check, size: 13),
        ),
        const SizedBox(width: 10),
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

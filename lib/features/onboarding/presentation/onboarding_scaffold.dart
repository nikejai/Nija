import 'package:flutter/material.dart';

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.child,
    this.maxContentWidth = 430,
    this.fullWidth = false,
  });

  final Widget child;
  final double maxContentWidth;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        color: colorScheme.surfaceContainerHighest,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: SizedBox(
                  width: fullWidth
                      ? constraints.maxWidth
                      : constraints.maxWidth > maxContentWidth
                      ? maxContentWidth
                      : constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: fullWidth
                          ? null
                          : Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: child,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

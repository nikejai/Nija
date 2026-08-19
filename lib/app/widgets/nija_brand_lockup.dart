import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../theme/entry_typography.dart';

enum NijaBrandLayout { horizontal, vertical }

class NijaBrandLockup extends StatelessWidget {
  const NijaBrandLockup({
    super.key,
    this.showMark = true,
    this.showTagline = false,
    this.markSize = 34,
    this.layout = NijaBrandLayout.horizontal,
    this.alignment = CrossAxisAlignment.start,
    this.nameStyle,
    this.nativeNameStyle,
    this.taglineStyle,
  });

  final bool showMark;
  final bool showTagline;
  final double markSize;
  final NijaBrandLayout layout;
  final CrossAxisAlignment alignment;
  final TextStyle Function(Color color)? nameStyle;
  final TextStyle Function(Color color)? nativeNameStyle;
  final TextStyle Function(Color color)? taglineStyle;

  Widget _buildNameRow(
    ColorScheme colorScheme, {
    required bool emphasizePrimaryName,
  }) {
    final resolvedNameStyle = (nameStyle ??
            (emphasizePrimaryName
                ? EntryTypography.heroTitle
                : EntryTypography.brandName))(
      colorScheme.onSurface,
    );
    final resolvedNativeStyle =
        (nativeNameStyle ?? EntryTypography.brandNativeName)(
          colorScheme.onSurfaceVariant,
        );

    if (layout == NijaBrandLayout.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            AppStrings.appName,
            key: const ValueKey('brand-name-nija'),
            style: resolvedNameStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.appNameBranding,
            key: const ValueKey('brand-name-native'),
            style: resolvedNativeStyle,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          AppStrings.appName,
          key: const ValueKey('brand-name-nija'),
          style: resolvedNameStyle,
        ),
        const SizedBox(width: 8),
        Text(
          AppStrings.appNameBranding,
          key: const ValueKey('brand-name-native'),
          style: resolvedNativeStyle,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final emphasizePrimaryName = layout == NijaBrandLayout.vertical;
    final nameRow = _buildNameRow(
      colorScheme,
      emphasizePrimaryName: emphasizePrimaryName,
    );
    final tagline = showTagline
        ? Text(
            AppStrings.tagline,
            style: (taglineStyle ?? EntryTypography.brandTagline)(
              colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: layout == NijaBrandLayout.vertical
                ? TextAlign.center
                : TextAlign.start,
          )
        : null;
    final mark = showMark
        ? Image.asset(
            'assets/branding/nija_mark.png',
            width: markSize,
            height: markSize,
          )
        : null;

    if (layout == NijaBrandLayout.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (mark != null) ...[mark, const SizedBox(height: 14)],
          nameRow,
          if (tagline != null) ...[const SizedBox(height: 8), tagline],
        ],
      );
    }

    if (mark == null) {
      return Column(
        crossAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          nameRow,
          if (tagline != null) ...[const SizedBox(height: 2), tagline],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        mark,
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: alignment,
            mainAxisSize: MainAxisSize.min,
            children: [
              nameRow,
              if (tagline != null) ...[const SizedBox(height: 2), tagline],
            ],
          ),
        ),
      ],
    );
  }
}

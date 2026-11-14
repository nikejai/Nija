import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/security/password_generator.dart';

class PasswordGeneratorSheet extends StatefulWidget {
  const PasswordGeneratorSheet({
    super.key,
    required this.fieldLabel,
    required this.onSelected,
  });

  final String fieldLabel;
  final ValueChanged<String> onSelected;

  static Future<void> show({
    required BuildContext context,
    required String fieldLabel,
    required ValueChanged<String> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PasswordGeneratorSheet(
        fieldLabel: fieldLabel,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<PasswordGeneratorSheet> createState() => _PasswordGeneratorSheetState();
}

class _PasswordGeneratorSheetState extends State<PasswordGeneratorSheet> {
  final _generator = PasswordGenerator();

  bool _isPassphrase = false;

  // Password options
  int _length = 20;
  bool _includeUpper = true;
  bool _includeLower = true;
  bool _includeDigits = true;
  bool _includeSymbols = true;

  // Passphrase options
  int _wordCount = 4;
  bool _capitalize = false;
  bool _includeNumber = true;

  String _generated = '';

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    setState(() {
      if (_isPassphrase) {
        _generated = _generator.generatePassphrase(
          PassphraseOptions(
            wordCount: _wordCount,
            capitalize: _capitalize,
            includeNumber: _includeNumber,
          ),
        );
      } else {
        _generated = _generator.generatePassword(
          PasswordGeneratorOptions(
            length: _length,
            includeUppercase: _includeUpper,
            includeLowercase: _includeLower,
            includeDigits: _includeDigits,
            includeSymbols: _includeSymbols,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final entropy = PasswordGenerator.calculateEntropyBits(_generated);
    final strength = PasswordGenerator.evaluateStrength(_generated);
    final strengthLabel = PasswordGenerator.strengthLabel(strength);

    final strengthColor = switch (strength) {
      PasswordStrength.weak => Colors.redAccent,
      PasswordStrength.fair => Colors.orangeAccent,
      PasswordStrength.strong => Colors.lightGreen,
      PasswordStrength.veryStrong => Colors.green,
    };

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Generate ${widget.fieldLabel}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Segmented mode switcher
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Random Password'),
                    icon: Icon(Icons.password),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Passphrase'),
                    icon: Icon(Icons.abc),
                  ),
                ],
                selected: {_isPassphrase},
                onSelectionChanged: (set) {
                  setState(() {
                    _isPassphrase = set.first;
                    _regenerate();
                  });
                },
              ),
              const SizedBox(height: 16),
              // Generated preview container
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _generated,
                            key: const ValueKey('generated-password-preview'),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('password-generator-regenerate'),
                          tooltip: 'Regenerate',
                          icon: const Icon(Icons.refresh),
                          onPressed: _regenerate,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: strengthColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$strengthLabel (${entropy.toStringAsFixed(0)} bits)',
                            style: TextStyle(
                              color: strengthColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Configuration controls
              if (!_isPassphrase) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Length',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '$_length',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                Slider(
                  value: _length.toDouble(),
                  min: 8,
                  max: 48,
                  divisions: 40,
                  onChanged: (val) {
                    setState(() {
                      _length = val.round();
                      _regenerate();
                    });
                  },
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('A-Z'),
                      selected: _includeUpper,
                      onSelected: (val) {
                        setState(() {
                          _includeUpper = val;
                          _regenerate();
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('a-z'),
                      selected: _includeLower,
                      onSelected: (val) {
                        setState(() {
                          _includeLower = val;
                          _regenerate();
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('0-9'),
                      selected: _includeDigits,
                      onSelected: (val) {
                        setState(() {
                          _includeDigits = val;
                          _regenerate();
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('!@#'),
                      selected: _includeSymbols,
                      onSelected: (val) {
                        setState(() {
                          _includeSymbols = val;
                          _regenerate();
                        });
                      },
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Words',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '$_wordCount',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                Slider(
                  value: _wordCount.toDouble(),
                  min: 3,
                  max: 8,
                  divisions: 5,
                  onChanged: (val) {
                    setState(() {
                      _wordCount = val.round();
                      _regenerate();
                    });
                  },
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Capitalize'),
                      selected: _capitalize,
                      onSelected: (val) {
                        setState(() {
                          _capitalize = val;
                          _regenerate();
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Include Number'),
                      selected: _includeNumber,
                      onSelected: (val) {
                        setState(() {
                          _includeNumber = val;
                          _regenerate();
                        });
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _generated));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('use-generated-password-btn'),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(
                        'Use this ${widget.fieldLabel.toLowerCase()}',
                      ),
                      onPressed: () {
                        widget.onSelected(_generated);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'adaptive_sheet.dart';

/// Shows how to put the web app on the phone's home screen (iPhone and
/// Android). The steps for the visitor's own phone come first.
Future<void> showInstallSheet(BuildContext context) =>
    showAdaptiveSheet<void>(context, builder: (_) => const InstallSteps());

class InstallSteps extends StatelessWidget {
  const InstallSteps({super.key});

  static const iphone = _Platform(
    title: 'iPhone',
    icon: Icons.phone_iphone,
    steps: [
      'Open this page in Safari. Other browsers on iPhone cannot install it.',
      'Tap the Share button (a square with an arrow pointing up) at the '
          'bottom of the screen.',
      'Scroll down and tap "Add to Home Screen".',
      'Tap "Add". The Baby Photobook icon is now on your home screen.',
    ],
  );

  static const android = _Platform(
    title: 'Android',
    icon: Icons.phone_android,
    steps: [
      'Open this page in Chrome.',
      'Tap the three dots (⋮) at the top right.',
      'Tap "Install app". On some phones it says "Add to Home screen".',
      'Tap "Install". The Baby Photobook icon is now on your home screen.',
    ],
  );

  @override
  Widget build(BuildContext context) {
    final onIphone = defaultTargetPlatform == TargetPlatform.iOS;
    final first = onIphone ? iphone : android;
    final second = onIphone ? android : iphone;
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Put Baby Photobook on your phone',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'There is nothing to download from a store. Add the page to '
              'your home screen and it opens like an app.',
            ),
            const SizedBox(height: 20),
            _Steps(first),
            const SizedBox(height: 20),
            _Steps(second),
            const SizedBox(height: 20),
            Text(
              'Afterwards, open Baby Photobook from the icon on your home '
              'screen. If it asks you to connect Google Drive again, do that '
              'and tap "I already registered my baby": your babies and photos '
              'come back from your Drive.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Platform {
  const _Platform({
    required this.title,
    required this.icon,
    required this.steps,
  });
  final String title;
  final IconData icon;
  final List<String> steps;
}

class _Steps extends StatelessWidget {
  const _Steps(this.platform);
  final _Platform platform;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(platform.icon, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(platform.title, style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < platform.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${i + 1}.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(child: Text(platform.steps[i])),
              ],
            ),
          ),
      ],
    );
  }
}

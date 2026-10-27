import 'package:flutter/material.dart';

import 'adaptive_sheet.dart';
import 'device_info.dart';
import 'install_demo.dart';
import 'install_info.dart';

/// Starts "put it on my phone": the browser's own install dialog when it
/// offers one (Chrome on Android), otherwise the steps for this phone.
Future<void> startInstall(BuildContext context) async {
  if (canPromptInstall() && await promptInstall()) return;
  if (!context.mounted) return;
  await showInstallSheet(context);
}

Future<void> showInstallSheet(BuildContext context) =>
    showAdaptiveSheet<void>(context, builder: (_) => const InstallSteps());

enum GuideId {
  iosSafari,
  iosChrome,
  androidChrome,
  androidSamsung,
  androidFirefox,
}

class InstallGuide {
  const InstallGuide({
    required this.id,
    required this.label,
    required this.icon,
    required this.steps,
    required this.demo,
    this.note,
  });
  final GuideId id;
  final String label;
  final IconData icon;
  final List<String> steps;
  final DemoStyle demo;
  final String? note;
}

const guides = <GuideId, InstallGuide>{
  GuideId.iosSafari: InstallGuide(
    id: GuideId.iosSafari,
    label: 'iPhone · Safari',
    icon: Icons.phone_iphone,
    steps: [
      'Tap the Share button at the bottom (a square with an arrow pointing up).',
      'Scroll down and tap "Add to Home Screen". If you do not see it, tap "View More" first.',
      'Tap "Add" at the top right.',
    ],
    demo: DemoStyle(
      shareAtBottom: true,
      shareIcon: Icons.ios_share,
      menuRow: 'Add to Home Screen',
    ),
  ),
  GuideId.iosChrome: InstallGuide(
    id: GuideId.iosChrome,
    label: 'iPhone · Chrome',
    icon: Icons.phone_iphone,
    steps: [
      'Tap the Share button at the top right, next to the address (a square with an arrow pointing up).',
      'Tap "Add to Home Screen".',
      'Tap "Add".',
    ],
    note: 'Needs iOS 16.4 or newer. On an older iPhone, open this page in Safari instead.',
    demo: DemoStyle(
      shareAtBottom: false,
      shareIcon: Icons.ios_share,
      menuRow: 'Add to Home Screen',
    ),
  ),
  GuideId.androidChrome: InstallGuide(
    id: GuideId.androidChrome,
    label: 'Android · Chrome',
    icon: Icons.phone_android,
    steps: [
      'Tap the three dots (⋮) at the top right.',
      'Tap "Install app" (or "Add to Home screen").',
      'Tap "Install".',
    ],
    demo: DemoStyle(
      shareAtBottom: false,
      shareIcon: Icons.more_vert,
      menuRow: 'Install app',
    ),
  ),
  GuideId.androidSamsung: InstallGuide(
    id: GuideId.androidSamsung,
    label: 'Android · Samsung',
    icon: Icons.phone_android,
    steps: [
      'Tap the menu (three lines) at the bottom right.',
      'Tap "Add page to", then "Home screen".',
      'Tap "Add".',
    ],
    demo: DemoStyle(
      shareAtBottom: true,
      shareIcon: Icons.menu,
      menuRow: 'Add page to',
    ),
  ),
  GuideId.androidFirefox: InstallGuide(
    id: GuideId.androidFirefox,
    label: 'Android · Firefox',
    icon: Icons.phone_android,
    steps: [
      'Tap the three dots (⋮) at the top right.',
      'Tap "Install".',
      'Tap "Add".',
    ],
    demo: DemoStyle(
      shareAtBottom: false,
      shareIcon: Icons.more_vert,
      menuRow: 'Install',
    ),
  ),
};

/// Which guide fits this visitor, and what to tell them before it.
({GuideId id, String? warning}) guideFor(DeviceInfo d) {
  const inApp =
      'You are in the browser built into another app (Instagram, Facebook, '
      'WhatsApp...). Tap the ⋯ or share icon there and choose "Open in '
      'browser", then follow these steps.';
  switch (d.os) {
    case Os.ios:
      return switch (d.browser) {
        Browser.safari => (id: GuideId.iosSafari, warning: null),
        Browser.chrome => (id: GuideId.iosChrome, warning: null),
        Browser.inApp => (id: GuideId.iosSafari, warning: inApp),
        _ => (
          id: GuideId.iosSafari,
          warning:
              'This browser cannot add the page to your home screen. Open '
              'this page in Safari (copy the address) and follow these steps.',
        ),
      };
    case Os.android:
      return switch (d.browser) {
        Browser.chrome => (id: GuideId.androidChrome, warning: null),
        Browser.samsung => (id: GuideId.androidSamsung, warning: null),
        Browser.firefox => (id: GuideId.androidFirefox, warning: null),
        Browser.inApp => (id: GuideId.androidChrome, warning: inApp),
        _ => (
          id: GuideId.androidChrome,
          warning:
              'Open this page in Chrome (copy the address) and follow these '
              'steps.',
        ),
      };
    case Os.other:
      return (
        id: GuideId.iosSafari,
        warning:
            'You are on a computer. Open this page on your phone, then follow '
            'the steps for your phone and browser.',
      );
  }
}

/// Test hook: pretend to be this device instead of reading the browser.
@visibleForTesting
DeviceInfo? debugDevice;

DeviceInfo currentDevice() =>
    debugDevice ?? parseDevice(userAgent(), touchPoints: touchPoints());

class InstallSteps extends StatefulWidget {
  const InstallSteps({super.key});

  @override
  State<InstallSteps> createState() => _InstallStepsState();
}

class _InstallStepsState extends State<InstallSteps> {
  late final DeviceInfo _device = currentDevice();
  late GuideId _selected = guideFor(_device).id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detected = guideFor(_device);
    final guide = guides[_selected]!;
    // The warning belongs to what we detected, not to a guide picked by hand.
    final warning = _selected == detected.id ? detected.warning : null;
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
            const SizedBox(height: 16),
            if (canPromptInstall()) ...[
              FilledButton.icon(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  if (await promptInstall()) nav.maybePop();
                },
                icon: const Icon(Icons.install_mobile),
                label: const Text('Install now'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Or follow the steps below.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
            ],
            if (_device.isPhone) ...[
              Text(
                'We think you use: ${guides[detected.id]!.label}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            if (warning != null) ...[
              _Warning(warning),
              const SizedBox(height: 16),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final g in guides.values)
                  ChoiceChip(
                    label: Text(g.label),
                    selected: g.id == _selected,
                    onSelected: (_) => setState(() => _selected = g.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: InstallDemo(key: ValueKey(guide.id), style: guide.demo),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < guide.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
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
                    Expanded(child: Text(guide.steps[i])),
                  ],
                ),
              ),
            if (guide.note != null)
              Text(guide.note!, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
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

class _Warning extends StatelessWidget {
  const _Warning(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: scheme.onTertiaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

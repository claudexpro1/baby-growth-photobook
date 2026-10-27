import 'dart:async';

import 'package:flutter/material.dart';

/// What differs between browsers in the little animation.
class DemoStyle {
  const DemoStyle({
    required this.shareAtBottom,
    required this.shareIcon,
    required this.menuRow,
  });

  /// The share/menu button sits in a bottom bar (Safari, Samsung) or in the
  /// top address bar (Chrome, Firefox).
  final bool shareAtBottom;
  final IconData shareIcon;

  /// The wording of the menu entry that adds the page.
  final String menuRow;
}

/// A looping mock-up of the three steps: tap the button, tap the menu entry,
/// the icon appears on the home screen. Not a recording: it only shows where
/// to look.
class InstallDemo extends StatefulWidget {
  const InstallDemo({super.key, required this.style});
  final DemoStyle style;

  @override
  State<InstallDemo> createState() => _InstallDemoState();
}

class _InstallDemoState extends State<InstallDemo> {
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 900),
      (_) => setState(() => _tick++),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final step = (_tick ~/ 3) % 3;
    final pulse = _tick.isEven;
    final s = widget.style;
    return Semantics(
      label: 'Animation of the three steps',
      excludeSemantics: true,
      child: Container(
        width: 190,
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.black87, width: 6),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: switch (step) {
            0 => _BrowserFrame(
              key: const ValueKey(0),
              style: s,
              pulse: pulse,
              accent: scheme.primary,
            ),
            1 => _MenuFrame(
              key: const ValueKey(1),
              row: s.menuRow,
              pulse: pulse,
              accent: scheme.primary,
            ),
            _ => _HomeFrame(key: const ValueKey(2), accent: scheme.primary),
          },
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.pulse, required this.accent, required this.child});
  final bool pulse;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: pulse ? 0.25 : 0.08),
        border: Border.all(color: accent, width: 2),
      ),
      child: child,
    );
  }
}

class _BrowserFrame extends StatelessWidget {
  const _BrowserFrame({
    super.key,
    required this.style,
    required this.pulse,
    required this.accent,
  });
  final DemoStyle style;
  final bool pulse;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final button = _Ring(
      pulse: pulse,
      accent: accent,
      child: Icon(style.shareIcon, size: 20, color: Colors.black87),
    );
    final address = Container(
      height: 34,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(17),
      ),
      alignment: Alignment.centerLeft,
      child: const Text('Baby Photobook', style: TextStyle(fontSize: 11)),
    );
    final top = style.shareAtBottom
        ? address
        : Row(
            children: [
              Expanded(child: address),
              button,
              const SizedBox(width: 6),
            ],
          );
    return Column(
      children: [
        top,
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 120, height: 14, color: accent),
                const SizedBox(height: 10),
                for (var i = 0; i < 5; i++) ...[
                  Container(
                    width: i.isEven ? 150 : 110,
                    height: 8,
                    color: Colors.black12,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
        if (style.shareAtBottom)
          Container(
            height: 48,
            color: Colors.black12,
            alignment: Alignment.center,
            child: button,
          ),
      ],
    );
  }
}

class _MenuFrame extends StatelessWidget {
  const _MenuFrame({
    super.key,
    required this.row,
    required this.pulse,
    required this.accent,
  });
  final String row;
  final bool pulse;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    Widget item(String text, {bool target = false}) => Container(
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: target
            ? accent.withValues(alpha: pulse ? 0.28 : 0.1)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: target ? Border.all(color: accent, width: 2) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: target ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
    return Container(
      color: Colors.black26,
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            item('Copy link'),
            item('Bookmark'),
            item(row, target: true),
            item('Print'),
          ],
        ),
      ),
    );
  }
}

class _HomeFrame extends StatelessWidget {
  const _HomeFrame({super.key, required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    Widget icon(Color c, String label) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 9)),
      ],
    );
    return Container(
      color: const Color(0xFFDCE6F2),
      padding: const EdgeInsets.fromLTRB(14, 40, 14, 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              icon(Colors.black26, 'Mail'),
              icon(Colors.black26, 'Maps'),
              icon(Colors.black26, 'Notes'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              icon(Colors.black26, 'Photos'),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.3, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: icon(accent, 'Photobook'),
              ),
              icon(Colors.black26, 'Clock'),
            ],
          ),
          const Spacer(),
          const Text(
            'Done: it is on your home screen',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

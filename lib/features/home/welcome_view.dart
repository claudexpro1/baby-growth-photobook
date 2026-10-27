import 'package:flutter/material.dart';

import '../../ui/responsive.dart';
import '../common/install_info.dart';
import '../common/install_sheet.dart';
import 'desktop_welcome.dart';

class _Palette {
  const _Palette(
    this.bg,
    this.accent,
    this.onAccent,
    this.soft,
    this.text,
    this.doodle,
  );
  final Color bg, accent, onAccent, soft, text;
  final double doodle; // opacity of the background doodles

  static const light = _Palette(
    Color(0xFFFFF6EE),
    Color(0xFFC4420F),
    Colors.white,
    Color(0xFFFFE1D1),
    Color(0xFF6B4F45),
    0.17,
  );
  static const dark = _Palette(
    Color(0xFF1E1613),
    Color(0xFFFF8A5B),
    Color(0xFF3B1000),
    Color(0xFF3A2219),
    Color(0xFFD9C2B8),
    0.12,
  );
}

/// Faint baby things scattered over the background: (emoji, x, y, turns), with
/// x and y as fractions of the screen.
const _doodles = <(String, double, double, double)>[
  ('👶', 0.05, 0.02, -0.03),
  ('🚗', 0.33, 0.02, 0.04),
  ('🍼', 0.61, 0.01, 0.1),
  ('⚽', 0.88, 0.0, 0.0),
  ('🧸', 0.17, 0.12, 0.0),
  ('🚀', 0.42, 0.11, 0.06),
  ('⭐', 0.68, 0.12, 0.0),
  ('🦖', 0.9, 0.13, 0.0),
  ('🧢', 0.3, 0.25, -0.04),
  ('🎀', 0.55, 0.25, 0.03),
  ('🧦', 0.02, 0.27, 0.08),
  ('🐻', 0.82, 0.26, 0.0),
  ('💙', 0.14, 0.37, -0.02),
  ('🏎️', 0.4, 0.37, -0.05),
  ('👶', 0.66, 0.37, 0.0),
  ('🚗', 0.92, 0.38, 0.0),
  ('🍼', 0.03, 0.5, 0.1),
  ('🧸', 0.5, 0.52, 0.0),
  ('🧢', 0.86, 0.53, 0.04),
  ('⭐', 0.16, 0.61, 0.0),
  ('🦖', 0.35, 0.64, 0.0),
  ('🎀', 0.03, 0.75, 0.0),
  ('🧸', 0.28, 0.76, 0.0),
  ('💙', 0.52, 0.73, 0.0),
  ('🏎️', 0.82, 0.76, 0.0),
  ('⚽', 0.9, 0.86, 0.0),
  ('🧸', 0.06, 0.92, 0.0),
  ('🚀', 0.3, 0.92, 0.0),
  ('⭐', 0.54, 0.94, 0.0),
  ('🦖', 0.82, 0.93, 0.0),
];

/// The first screen: warm background with faint baby doodles, a big friendly
/// headline and two pill buttons.
class WelcomeView extends StatefulWidget {
  const WelcomeView({
    super.key,
    required this.onStart,
    required this.onRestore,
    this.busy = false,
  });
  final VoidCallback onStart;
  final VoidCallback onRestore;
  final bool busy;

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  static const _minGap = 32.0;

  final _columnKey = GlobalKey();

  /// Height of each of the two gaps (title to text, text to buttons). Starts
  /// small and is set after the first layout so both are equal and the buttons
  /// end at the bottom; when the content does not fit the page just scrolls.
  double _gap = _minGap;
  double _viewHeight = 0;
  double _vPadding = 0;

  void _fitGaps() {
    final box = _columnKey.currentContext?.findRenderObject() as RenderBox?;
    if (!mounted || box == null || !box.hasSize || _viewHeight <= 0) return;
    final natural = box.size.height - 2 * _gap;
    final room = (_viewHeight - _vPadding - natural) / 2;
    final next = room < _minGap ? _minGap : room;
    if ((next - _gap).abs() > 0.5) setState(() => _gap = next);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark
        ? _Palette.dark
        : _Palette.light;
    final width = MediaQuery.sizeOf(context).width;
    if (context.isWide) {
      return DesktopWelcome(
        onStart: widget.onStart,
        onRestore: widget.onRestore,
        busy: widget.busy,
      );
    }
    // On a laptop the content sits in a centred column instead of stretching
    // across the whole window.
    final wide = width > 700;
    final headline = wide ? 60.0 : (width * 0.125).clamp(34.0, 56.0);
    final doodle = wide ? 56.0 : 40.0;
    return ColoredBox(
      color: c.bg,
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: LayoutBuilder(
                builder: (context, box) => Stack(
                  children: [
                    for (final (emoji, x, y, turns) in _doodles)
                      Positioned(
                        left: x * box.maxWidth,
                        top: y * box.maxHeight,
                        child: Opacity(
                          opacity: c.doodle,
                          child: Transform.rotate(
                            angle: turns * 6.2832,
                            child: Text(
                              emoji,
                              style: TextStyle(fontSize: doodle),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, view) {
                _viewHeight = view.maxHeight;
                _vPadding = (wide ? 72 : 48) + (wide ? 56 : 24);
                WidgetsBinding.instance.addPostFrameCallback((_) => _fitGaps());
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: view.maxHeight),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            wide ? 72 : 48,
                            24,
                            wide ? 56 : 24,
                          ),
                          child: Column(
                            key: _columnKey,
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Baby Photobook',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  fontVariations: const [
                                    FontVariation('wght', 700),
                                  ],
                                  color: c.accent,
                                ),
                              ),
                              SizedBox(height: _gap),
                              Text(
                                'A few photos, kept with care',
                                style: TextStyle(
                                  fontSize: headline,
                                  height: 1.05,
                                  fontWeight: FontWeight.w800,
                                  fontVariations: const [
                                    FontVariation('wght', 800),
                                  ],
                                  color: c.accent,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'One photo now and then, saved in your own Drive, '
                                'becomes a story you will treasure.',
                                style: TextStyle(
                                  fontSize: 18,
                                  height: 1.45,
                                  color: c.text,
                                ),
                              ),
                              SizedBox(height: _gap),
                              FilledButton(
                                onPressed: widget.onStart,
                                style: FilledButton.styleFrom(
                                  backgroundColor: c.accent,
                                  foregroundColor: c.onAccent,
                                  minimumSize: const Size.fromHeight(60),
                                  shape: const StadiumBorder(),
                                  textStyle: const TextStyle(
                                    fontFamily: 'DMSans',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    fontVariations: [
                                      FontVariation('wght', 700),
                                    ],
                                  ),
                                ),
                                child: const Text('Start with your baby'),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: widget.busy
                                    ? null
                                    : widget.onRestore,
                                icon: const Icon(Icons.cloud_download_outlined),
                                label: const Text(
                                  'I already registered my baby',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: c.soft,
                                  foregroundColor: c.accent,
                                  minimumSize: const Size.fromHeight(56),
                                  shape: const StadiumBorder(),
                                  textStyle: const TextStyle(
                                    fontFamily: 'DMSans',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    fontVariations: [
                                      FontVariation('wght', 600),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'You need a Google account: your photos are '
                                'saved in your own Google Drive.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: c.text,
                                ),
                              ),
                              if (!isInstalledApp()) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => startInstall(context),
                                  icon: const Icon(Icons.install_mobile),
                                  label: const Text(
                                    'Add to your phone\'s home screen',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: c.accent,
                                    side: BorderSide(color: c.accent, width: 2),
                                    minimumSize: const Size.fromHeight(52),
                                    shape: const StadiumBorder(),
                                    textStyle: const TextStyle(
                                      fontFamily: 'DMSans',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      fontVariations: [
                                        FontVariation('wght', 600),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

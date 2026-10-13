import 'package:flutter/material.dart';

const _cream = Color(0xFFFFF6EE);
const _orange = Color(0xFFC4420F);
const _peach = Color(0xFFFFE1D1);
const _brown = Color(0xFF6B4F45);

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
class WelcomeView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // On a laptop the content sits in a centred column instead of stretching
    // across the whole window.
    final wide = width > 700;
    final headline = wide ? 60.0 : (width * 0.125).clamp(34.0, 56.0);
    final doodle = wide ? 56.0 : 40.0;
    return ColoredBox(
      color: _cream,
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: LayoutBuilder(
                builder: (context, c) => Stack(
                  children: [
                    for (final (emoji, x, y, turns) in _doodles)
                      Positioned(
                        left: x * c.maxWidth,
                        top: y * c.maxHeight,
                        child: Opacity(
                          opacity: 0.17,
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
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Baby Photobook',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                fontVariations: [FontVariation('wght', 700)],
                                color: _orange,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'A few photos, kept with care',
                              style: TextStyle(
                                fontSize: headline,
                                height: 1.05,
                                fontWeight: FontWeight.w800,
                                fontVariations: const [
                                  FontVariation('wght', 800),
                                ],
                                color: _orange,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'One photo now and then, saved in your own Drive, '
                              'becomes a story you will treasure.',
                              style: TextStyle(
                                fontSize: 18,
                                height: 1.45,
                                color: _brown,
                              ),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: onStart,
                              style: FilledButton.styleFrom(
                                backgroundColor: _orange,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(60),
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                  fontFamily: 'DMSans',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  fontVariations: [FontVariation('wght', 700)],
                                ),
                              ),
                              child: const Text('Start with your baby'),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: busy ? null : onRestore,
                              icon: const Icon(Icons.cloud_download_outlined),
                              label: const Text('I already registered my baby'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _peach,
                                foregroundColor: _orange,
                                minimumSize: const Size.fromHeight(56),
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                  fontFamily: 'DMSans',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  fontVariations: [FontVariation('wght', 600)],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

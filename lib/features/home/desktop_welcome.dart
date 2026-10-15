import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ui/adaptive_scaffold.dart';
import '../../ui/responsive.dart';

const _accent = Color(0xFFC4420F);
const _cream = Color(0xFFFFF6EE);
const _soft = Color(0xFFFFE1D1);
const _ink = Color(0xFF3B2A24);
const _muted = Color(0xFF6B4F45);

const privacyPolicyUrl =
    'https://github.com/claudexpro1/baby-growth-photobook/blob/main/docs/PRIVACY_POLICY.md';

/// The first screen on a laptop or desktop: a proper landing page with a hero,
/// how it works, what stays private, and a footer. Phones keep the compact
/// start screen.
class DesktopWelcome extends StatelessWidget {
  const DesktopWelcome({
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
    final narrow = !context.isDesktop;
    return ColoredBox(
      color: _cream,
      child: SafeArea(
        child: SingleChildScrollView(
          child: ContentFrame(
            maxWidth: 1180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _topBar(),
                narrow
                    ? Column(
                        children: [
                          _heroText(narrow),
                          const SizedBox(height: 48),
                          const _HeroVisual(),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 6, child: _heroText(narrow)),
                          const SizedBox(width: 48),
                          const Expanded(flex: 5, child: _HeroVisual()),
                        ],
                      ),
                const SizedBox(height: 96),
                _sectionTitle('How it works'),
                const SizedBox(height: 28),
                _steps(narrow),
                const SizedBox(height: 96),
                _privacy(narrow),
                const SizedBox(height: 72),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() => SizedBox(
    height: 88,
    child: Row(
      children: [
        const BrandMark(size: 38),
        const SizedBox(width: 12),
        const Text(
          'Baby Photobook',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _accent,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: busy ? null : onRestore,
          icon: const Icon(Icons.cloud_download_outlined, size: 20),
          label: const Text('I already registered my baby'),
          style: TextButton.styleFrom(foregroundColor: _accent),
        ),
      ],
    ),
  );

  Widget _heroText(bool narrow) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _soft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Private  ·  Free  ·  In your own Google Drive',
            style: TextStyle(
              color: _accent,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'A few photos,\nkept with care',
          style: TextStyle(
            fontSize: narrow ? 52 : 68,
            height: 1.02,
            fontWeight: FontWeight.w800,
            color: _accent,
          ),
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520),
          child: Text(
            'One photo now and then, saved in your own Drive, becomes a story '
            'you will treasure. Daily at first, then weekly, then monthly: '
            'you decide the rhythm, and a reminder finds you.',
            style: TextStyle(fontSize: 19, height: 1.5, color: _muted),
          ),
        ),
        const SizedBox(height: 36),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 60),
                padding: const EdgeInsets.symmetric(horizontal: 36),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Start with your baby'),
            ),
            FilledButton.icon(
              onPressed: busy ? null : onRestore,
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('I already registered my baby'),
              style: FilledButton.styleFrom(
                backgroundColor: _soft,
                foregroundColor: _accent,
                minimumSize: const Size(0, 60),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'You need a Google account: your photos are saved in your own Google Drive. '
          'There is no sign-up with us.',
          style: TextStyle(fontSize: 14, color: _muted),
        ),
      ],
    ),
  );

  Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      color: _ink,
    ),
  );

  Widget _steps(bool narrow) {
    const items = [
      (
        '1',
        'Tell us about your baby',
        'A name, the birth date and, if you like, colours for the story. '
            'That is all it takes to begin.',
      ),
      (
        '2',
        'Choose your rhythm',
        'Daily in the first weeks, then weekly, then monthly, or anything you '
            'prefer. A reminder lands in your Google Calendar.',
      ),
      (
        '3',
        'Watch the story grow',
        'Every photo is saved in your Drive and appears on a timeline with '
            'milestones, ready to share as a PDF or a link.',
      ),
    ];
    final cards = [
      for (final (n, title, text) in items)
        _InfoCard(
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: _accent,
            child: Text(
              n,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          title: title,
          text: text,
        ),
    ];
    return _threeUp(cards, narrow);
  }

  Widget _privacy(bool narrow) {
    const items = [
      (
        Icons.folder_special_outlined,
        'Your Drive, your photos',
        'The app only sees the folder it creates. It cannot read the rest of '
            'your Drive.',
      ),
      (
        Icons.shield_outlined,
        'No server of ours',
        'Nothing is sent to us, so nobody else, including the developer, can '
            'see your photos or your baby\'s details.',
      ),
      (
        Icons.link,
        'Share only if you choose',
        'Photos stay private until you create a share link yourself, and you '
            'can stop sharing at any time.',
      ),
    ];
    return Container(
      padding: EdgeInsets.all(narrow ? 28 : 48),
      decoration: BoxDecoration(
        color: _soft.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Private by design'),
          const SizedBox(height: 28),
          _threeUp([
            for (final (icon, title, text) in items)
              _InfoCard(
                leading: Icon(icon, size: 34, color: _accent),
                title: title,
                text: text,
                plain: true,
              ),
          ], narrow),
        ],
      ),
    );
  }

  Widget _threeUp(List<Widget> cards, bool narrow) => narrow
      ? Column(
          children: [
            for (final c in cards)
              Padding(padding: const EdgeInsets.only(bottom: 16), child: c),
          ],
        )
      : IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 24),
                Expanded(child: cards[i]),
              ],
            ],
          ),
        );

  Widget _footer() => Column(
    children: [
      Divider(color: _accent.withValues(alpha: 0.18)),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            const BrandMark(size: 24),
            const SizedBox(width: 8),
            const Text(
              'Baby Photobook',
              style: TextStyle(fontWeight: FontWeight.w700, color: _muted),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(privacyPolicyUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Privacy policy'),
            ),
          ],
        ),
      ),
    ],
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.leading,
    required this.title,
    required this.text,
    this.plain = false,
  });
  final Widget leading;
  final String title;
  final String text;

  /// No white card behind it (used on the tinted privacy band).
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading,
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 16, height: 1.5, color: _muted),
        ),
      ],
    );
    return plain
        ? body
        : Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _accent.withValues(alpha: 0.12)),
            ),
            child: body,
          );
  }
}

/// A stack of tilted "photo cards", the way the timeline will look.
class _HeroVisual extends StatelessWidget {
  const _HeroVisual();

  @override
  Widget build(BuildContext context) {
    Widget photo(String label, String emoji, List<Color> colors, double angle) {
      return Transform.rotate(
        angle: angle * math.pi / 180,
        child: Container(
          width: 210,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 210,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 84)),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 500,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: 0,
            top: 120,
            child: photo('1 year', '🎂', const [
              Color(0xFFFFD9A0),
              Color(0xFFF2A65A),
            ], 7),
          ),
          Positioned(
            left: 0,
            top: 30,
            child: photo('Birth day', '👶', const [
              Color(0xFFF6B7C5),
              Color(0xFFE58FA6),
            ], -6),
          ),
          Positioned(
            left: 70,
            bottom: 0,
            child: photo('100 days', '🧸', const [
              Color(0xFFBFD9F2),
              Color(0xFF8DB7E3),
            ], 2),
          ),
          Positioned(
            right: 8,
            top: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_available, color: _accent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Time for Luna's photo",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _ink,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

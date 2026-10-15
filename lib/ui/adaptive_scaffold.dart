import 'package:flutter/material.dart';

import 'responsive.dart';

/// The little orange camera tile that is the app's mark (same look as the
/// favicon).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFC4420F),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        Icons.photo_camera_rounded,
        color: const Color(0xFFFFF6EE),
        size: size * 0.58,
      ),
    );
  }
}

/// A page frame that looks like a phone app on a phone and like a website on
/// wider windows: a top bar with the brand, a breadcrumb and the actions,
/// and the body centred below it.
///
/// [title] is the page's name. On the first page (no [crumbs]) the bar only
/// shows the brand; deeper pages show "Baby Photobook › [title]".
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
    this.showTitle = true,
    this.maxWidth = 1180,
    this.bodyPadded = true,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  /// False on the home page: the brand already says it.
  final bool showTitle;
  final double maxWidth;

  /// Wrap [body] in a centred [ContentFrame]. Pages that lay out their own
  /// panes pass false and use a frame themselves.
  final bool bodyPadded;

  @override
  Widget build(BuildContext context) {
    if (!context.isWide) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        floatingActionButton: floatingActionButton,
        body: body,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      body: Column(
        children: [
          Material(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A201C)
                : Colors.white,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: ContentFrame(
                  maxWidth: maxWidth,
                  child: SizedBox(
                    height: 64,
                    child: Row(
                      children: [
                        if (canPop)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: IconButton(
                              tooltip: 'Back',
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                          ),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: canPop
                              ? () =>
                                    Navigator.of(context)
                                        .popUntil((r) => r.isFirst)
                              : null,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              canPop ? 6 : 0,
                              4,
                              6,
                              4,
                            ),
                            child: Row(
                              children: [
                                const BrandMark(),
                                const SizedBox(width: 10),
                                Text(
                                  'Baby Photobook',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (showTitle) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.chevron_right,
                              color: scheme.outline,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ] else
                          const Spacer(),
                        ...actions,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: bodyPadded
                ? ContentFrame(maxWidth: maxWidth, child: body)
                : body,
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

import 'package:flutter/material.dart';

/// Width classes. The phone layout is the one the app was designed for; wider
/// windows get a centred column (tablet) or two panes (desktop).
enum ScreenClass { phone, tablet, desktop }

const tabletBreakpoint = 700.0;
const desktopBreakpoint = 1000.0;

ScreenClass screenClassFor(double width) => width >= desktopBreakpoint
    ? ScreenClass.desktop
    : width >= tabletBreakpoint
    ? ScreenClass.tablet
    : ScreenClass.phone;

extension ScreenContext on BuildContext {
  ScreenClass get screen => screenClassFor(MediaQuery.sizeOf(this).width);

  /// True on tablets and desktops: the window is wide enough for a web layout.
  bool get isWide => screen != ScreenClass.phone;
  bool get isDesktop => screen == ScreenClass.desktop;
}

/// Centres [child] in a column of at most [maxWidth], with side padding that
/// grows with the window. On a phone it only adds the usual 16px.
class ContentFrame extends StatelessWidget {
  const ContentFrame({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.phonePadding = 16,
  });
  final Widget child;
  final double maxWidth;
  final double phonePadding;

  @override
  Widget build(BuildContext context) {
    final pad = switch (context.screen) {
      ScreenClass.phone => phonePadding,
      ScreenClass.tablet => 24.0,
      ScreenClass.desktop => 32.0,
    };
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth + 2 * pad),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: child,
        ),
      ),
    );
  }
}

/// Lifts a card slightly while the mouse is over it (desktop only; touch
/// screens never report a hover).
class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.child, this.radius = 20});
  final Widget child;
  final double radius;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}

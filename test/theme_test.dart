import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/features/home/welcome_view.dart';
import 'package:baby_growth_photobook/main.dart';
import 'package:baby_growth_photobook/ui/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'neutral is the start screen orange; girl and boy keep pink and blue',
    () {
      final n = buildTheme(Gender.neutral).colorScheme;
      expect(n.primary, brandOrange);
      expect(
        buildTheme(Gender.neutral).scaffoldBackgroundColor,
        const Color(0xFFFFF6EE),
      );
      final g = buildTheme(Gender.girl).colorScheme.primary;
      final b = buildTheme(Gender.boy).colorScheme.primary;
      expect(HSLColor.fromColor(g).hue, inInclusiveRange(320, 360)); // pink
      expect(HSLColor.fromColor(b).hue, inInclusiveRange(190, 230)); // blue
      expect(g, isNot(n.primary));
    },
  );

  test('dark mode: lighter orange on a warm dark background', () {
    final d = buildTheme(Gender.neutral, brightness: Brightness.dark);
    expect(d.colorScheme.primary, const Color(0xFFFF8A5B));
    expect(d.scaffoldBackgroundColor, const Color(0xFF1E1613));
    expect(d.colorScheme.brightness, Brightness.dark);
    for (final g in Gender.values) {
      expect(
        buildTheme(g, brightness: Brightness.dark).scaffoldBackgroundColor,
        const Color(0xFF1E1613),
      );
    }
  });

  testWidgets('themeFor stays light even when the phone is in dark mode', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    late ThemeData got;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            got = themeFor(c, Gender.girl);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(got.brightness, Brightness.light);
    expect(got.scaffoldBackgroundColor, const Color(0xFFFFF6EE));
  });

  testWidgets('start screen has a dark version', (tester) async {
    Future<Color> bg(Brightness b) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Gender.neutral, brightness: b),
          home: Scaffold(
            body: WelcomeView(onStart: () {}, onRestore: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final box = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(WelcomeView),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      return box.color;
    }

    expect(await bg(Brightness.light), const Color(0xFFFFF6EE));
    expect(await bg(Brightness.dark), const Color(0xFF1E1613));
  });

  testWidgets('the whole app stays light in phone dark mode', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const ProviderScope(child: PhotobookApp()));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(app.darkTheme, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

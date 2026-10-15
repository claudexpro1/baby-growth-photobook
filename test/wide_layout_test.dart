import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/features/baby/baby_page.dart';
import 'package:baby_growth_photobook/features/home/home_page.dart';

import 'package:baby_growth_photobook/data/photo_library.dart';
import 'package:baby_growth_photobook/features/baby/photo_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show MemoryRepository;

Baby _baby(String id, String name) => Baby(
  id: id,
  name: name,
  gender: Gender.girl,
  birth: DateTime.now().subtract(const Duration(days: 40)),
  phases: const [Phase(start: Age.birth, frequency: Frequency.weekly)],
);

/// A real 1x1 PNG.
final _png = Uint8List.fromList(const [
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  255,
  255,
  63,
  0,
  5,
  254,
  2,
  254,
  167,
  53,
  129,
  132,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
]);

void main() {
  Future<void> open(
    WidgetTester t,
    Size size,
    Widget home,
    List<Baby> babies,
  ) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final repo = MemoryRepository()..data = babies;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWith((_) async => MemoryStore()),
          babyRepositoryProvider.overrideWith((_) async => repo),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 150)));
    await t.pumpAndSettle();
  }

  testWidgets('desktop home: top bar, grid of cards, add tile, no FAB', (
    t,
  ) async {
    await open(t, const Size(1440, 900), const HomePage(), [
      _baby('a', 'Anna'),
      _baby('b', 'Ben'),
    ]);
    expect(find.text('Your babies'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Ben'), findsOneWidget);
    expect(find.text('Add a baby'), findsNWidgets(2)); // header button + tile
    expect(find.byType(FloatingActionButton), findsNothing);
    // cards sit side by side, not stacked full width
    final a = t.getTopLeft(find.text('Anna')).dy;
    final b = t.getTopLeft(find.text('Ben')).dy;
    expect(a, b);
    expect(t.takeException(), isNull);
  });

  testWidgets('phone home keeps the list and the floating button', (t) async {
    await open(t, const Size(400, 800), const HomePage(), [_baby('a', 'Anna')]);
    expect(find.text('Your babies'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('desktop baby page: side panel with actions and a timeline', (
    t,
  ) async {
    await open(t, const Size(1440, 900), const BabyPage(babyId: 'a'), [
      _baby('a', 'Anna'),
    ]);
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget); // visible, not in a menu
    expect(find.text('Share photobook (PDF)'), findsOneWidget);
    expect(find.text('Baby Photobook'), findsOneWidget); // top bar brand
    // the side panel is on the left of the timeline
    expect(
      t.getTopLeft(find.text('Settings')).dx,
      lessThan(t.getTopLeft(find.text('Timeline')).dx),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('tablet baby page: one centred column, no side panel', (t) async {
    await open(t, const Size(800, 1000), const BabyPage(babyId: 'a'), [
      _baby('a', 'Anna'),
    ]);
    expect(find.text('Timeline'), findsNothing);
    expect(find.text('Share photobook (PDF)'), findsNothing); // in the menu
    expect(t.takeException(), isNull);
  });

  testWidgets('desktop start screen is a landing page', (t) async {
    await open(t, const Size(1440, 900), const HomePage(), []);
    expect(find.text('Start with your baby'), findsOneWidget);
    expect(find.text('How it works'), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('Private by design'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Private by design'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
  });

  testWidgets(
    'desktop photo viewer: arrow buttons and keys move between photos',
    (t) async {
      final store = MemoryStore();
      final lib = PhotoLibrary(store, 'photos/a');
      await t.runAsync(() async {
        await lib.add(_png, DateTime(2026, 10, 1));
        await lib.add(_png, DateTime(2026, 10, 8));
      });
      t.view.physicalSize = const Size(1440, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final repo = MemoryRepository()
        ..data = [_baby('a', 'Anna').copyWith(birth: DateTime(2026, 10, 1))];
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            localStoreProvider.overrideWith((_) async => store),
            babyRepositoryProvider.overrideWith((_) async => repo),
          ],
          child: const MaterialApp(home: PhotoViewer(babyId: 'a', initial: 0)),
        ),
      );
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
      await t.pumpAndSettle();
      expect(find.textContaining('Birth day'), findsOneWidget);
      expect(find.byTooltip('Next photo'), findsOneWidget);
      await t.tap(find.byTooltip('Next photo'));
      await t.pumpAndSettle();
      expect(find.textContaining('7 days'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pumpAndSettle();
      expect(find.textContaining('Birth day'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
      expect(find.textContaining('7 days'), findsOneWidget);
    },
  );
}

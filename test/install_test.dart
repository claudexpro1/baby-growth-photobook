import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/features/common/install_sheet.dart';
import 'package:baby_growth_photobook/features/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show MemoryRepository;
import 'photo_sync_test.dart' show FakeCloud;

void main() {
  testWidgets('install steps cover iPhone and Android', (t) async {
    t.view.physicalSize = const Size(400, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: InstallSteps())));
    expect(find.text('iPhone'), findsOneWidget);
    expect(find.text('Android'), findsOneWidget);
    expect(find.textContaining('Add to Home Screen'), findsOneWidget);
    expect(find.textContaining('Install app'), findsOneWidget);
  });

  testWidgets('the iPhone steps come first on an iPhone', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    t.view.physicalSize = const Size(400, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: InstallSteps())));
    final iphoneY = t.getTopLeft(find.text('iPhone')).dy;
    final androidY = t.getTopLeft(find.text('Android')).dy;
    debugDefaultTargetPlatformOverride = null;
    expect(iphoneY, lessThan(androidY));
  });

  testWidgets('home banner shows once, "Not now" hides it for good', (t) async {
    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final store = MemoryStore();
    final repo = MemoryRepository()
      ..data = [
        Baby(
          id: 'a',
          name: 'Anna',
          gender: Gender.girl,
          birth: DateTime.now().subtract(const Duration(days: 4)),
          phases: const [Phase(start: Age.birth, frequency: Frequency.weekly)],
        ),
      ];
    Future<void> open() async {
      await t.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            localStoreProvider.overrideWith((_) async => store),
            babyRepositoryProvider.overrideWith((_) async => repo),
            cloudProvider.overrideWithValue(FakeCloud()),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );
      await t.pumpAndSettle();
    }

    await open();
    expect(find.text('Add Baby Photobook to your home screen'), findsOneWidget);
    await t.tap(find.text('Show me how'));
    await t.pumpAndSettle();
    expect(find.text('Put Baby Photobook on your phone'), findsOneWidget);
    Navigator.of(t.element(find.text('Put Baby Photobook on your phone')))
        .pop();
    await t.pumpAndSettle();
    await t.tap(find.text('Not now'));
    await t.pumpAndSettle();
    expect(find.text('Add Baby Photobook to your home screen'), findsNothing);
    await open();
    expect(find.text('Add Baby Photobook to your home screen'), findsNothing);
  });
}

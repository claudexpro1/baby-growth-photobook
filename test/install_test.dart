import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/features/common/device_info.dart';
import 'package:baby_growth_photobook/features/common/install_sheet.dart';
import 'package:baby_growth_photobook/features/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show MemoryRepository;
import 'photo_sync_test.dart' show FakeCloud;

void main() {
  tearDown(() => debugDevice = null);

  Future<void> openSteps(WidgetTester t) async {
    t.view.physicalSize = const Size(400, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: InstallSteps())));
  }

  testWidgets('Chrome on iPhone gets the address-bar Share steps', (t) async {
    debugDevice = parseDevice(
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) CriOS/124.0 Mobile/15E148 Safari/604.1',
    );
    await openSteps(t);
    expect(
      find.textContaining('at the top right, next to the address'),
      findsOneWidget,
    );
    expect(find.textContaining('iOS 16.4'), findsOneWidget);
    expect(find.textContaining('Open this page in Safari'), findsNothing);
  });

  testWidgets('Safari on iPhone gets the bottom Share steps', (t) async {
    debugDevice = parseDevice(
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
    );
    await openSteps(t);
    expect(find.textContaining('Share button at the bottom'), findsOneWidget);
  });

  testWidgets('Instagram browser is told to open the page elsewhere', (
    t,
  ) async {
    debugDevice = parseDevice(
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) Mobile/15E148 Instagram 330.0',
    );
    await openSteps(t);
    expect(find.textContaining('built into another app'), findsOneWidget);
  });

  testWidgets('a computer is told to use the phone', (t) async {
    debugDevice = parseDevice(
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0 Safari/537.36',
    );
    await openSteps(t);
    expect(find.textContaining('You are on a computer'), findsOneWidget);
  });

  testWidgets('picking another phone shows its steps', (t) async {
    debugDevice = const DeviceInfo(Os.android, Browser.chrome);
    await openSteps(t);
    expect(find.textContaining('three dots'), findsOneWidget);
    await t.tap(find.text('iPhone · Safari'));
    await t.pump();
    expect(find.textContaining('Share button at the bottom'), findsOneWidget);
  });

  test('parseDevice recognises the common browsers', () {
    DeviceInfo p(String ua, {int touch = 0}) =>
        parseDevice(ua, touchPoints: touch);
    expect(
      p(
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) Chrome/124.0 Mobile Safari/537.36',
      ).browser,
      Browser.chrome,
    );
    expect(
      p(
        'Mozilla/5.0 (Linux; Android 14; SM-S911B) SamsungBrowser/24.0 Chrome/117.0 Mobile Safari/537.36',
      ).browser,
      Browser.samsung,
    );
    expect(
      p('Mozilla/5.0 (Android 14; Mobile; rv:125.0) Gecko/125.0 Firefox/125.0')
          .browser,
      Browser.firefox,
    );
    expect(
      p(
        'Mozilla/5.0 (Linux; Android 14; Pixel 8; wv) Chrome/124.0 Mobile Safari/537.36',
      ).browser,
      Browser.inApp,
    );
    expect(
      p(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) FxiOS/124.0 Mobile/15E148 Safari/605.1.15',
      ).browser,
      Browser.firefox,
    );
    // An iPad asks for the desktop site and says "Macintosh".
    expect(
      p(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/17.4 Safari/605.1.15',
        touch: 5,
      ).os,
      Os.ios,
    );
    expect(
      p(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/17.4 Safari/605.1.15',
      ).os,
      Os.other,
    );
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

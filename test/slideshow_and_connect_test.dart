import 'dart:typed_data';

import 'package:baby_growth_photobook/data/cloud_storage.dart';
import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/photo_library.dart';
import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/features/baby/slideshow.dart';
import 'package:baby_growth_photobook/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show MemoryRepository;

class _SignedOutCloud implements CloudStorage {
  int signIns = 0;
  @override
  Future<bool> isSignedIn() async => false;
  @override
  Future<void> signIn() async => signIns++;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

void main() {
  testWidgets(
    'onboarding: Drive asks for consent first; Not now signs in nothing',
    (tester) async {
      final cloud = _SignedOutCloud();
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStoreProvider.overrideWith((_) async => MemoryStore()),
            babyRepositoryProvider.overrideWith(
              (_) async => MemoryRepository(),
            ),
            cloudProvider.overrideWithValue(cloud),
          ],
          child: const PhotobookApp(),
        ),
      );
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('becomes a story you will treasure'),
        findsOneWidget,
      );
      expect(find.text('I already registered my baby'), findsOneWidget);

      await tester.tap(find.text('Start with your baby'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Luna');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Connect Google Drive'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Before you connect Google Drive'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(cloud.signIns, 0);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Connect Google Drive'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(cloud.signIns, 1);
    },
  );

  testWidgets('slideshow advances through the photos and pauses on tap', (
    tester,
  ) async {
    final baby = Baby(
      id: 'b',
      name: 'Luna',
      gender: Gender.girl,
      birth: DateTime(2026, 10, 10),
      phases: const [Phase(start: Age.birth, frequency: Frequency.daily)],
    );
    final store = MemoryStore();
    final lib = PhotoLibrary(store, 'photos/b');
    // 1x1 transparent PNG
    final png = Uint8List.fromList(const [
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
    await tester.runAsync(() async {
      await lib.add(png, DateTime(2026, 10, 10));
      await lib.add(png, DateTime(2026, 10, 17));
    });
    final repo = MemoryRepository()..data = [baby];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWith((_) async => store),
          babyRepositoryProvider.overrideWith((_) async => repo),
        ],
        child: const MaterialApp(
          home: SlideshowPage(
            babyId: 'b',
            interval: Duration(milliseconds: 200),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('Birth day'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('7 days'), findsOneWidget);

    await tester.tap(find.byKey(const Key('slideshow-surface')));
    await tester.pump();
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('7 days'), findsOneWidget); // paused: did not move on
    await tester.pumpWidget(const SizedBox());
  });
}

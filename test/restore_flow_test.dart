import 'dart:convert';
import 'dart:typed_data';

import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/features/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show MemoryRepository;
import 'photo_sync_test.dart' show FakeCloud;

void main() {
  Future<void> open(WidgetTester tester, FakeCloud cloud) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWith((_) async => MemoryStore()),
          babyRepositoryProvider.overrideWith((_) async => MemoryRepository()),
          cloudProvider.overrideWithValue(cloud),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('"I already registered my baby" lands on the list of babies', (
    tester,
  ) async {
    final cloud = FakeCloud();
    final saved = Baby(
      id: 'b',
      name: 'Luna',
      gender: Gender.girl,
      birth: DateTime(2026, 10, 10),
      phases: const [Phase(start: Age.birth, frequency: Frequency.daily)],
    );
    cloud.appData['profile_b.json'] = Uint8List.fromList(
      utf8.encode(jsonEncode(saved.toJson())),
    );
    await open(tester, cloud);
    await tester.tap(find.text('I already registered my baby'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsOneWidget); // the baby card
    expect(find.text('Add a baby'), findsOneWidget); // the main page
    expect(find.text('Start with your baby'), findsNothing);
  });

  testWidgets('nothing in Drive: a clear message, not silence', (tester) async {
    await open(tester, FakeCloud());
    await tester.tap(find.text('I already registered my baby'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing to bring back'), findsOneWidget);
  });

  testWidgets('the main page has no cloud icon; restore is in the menu', (
    tester,
  ) async {
    final cloud = FakeCloud();
    await open(tester, cloud);
    // Put one baby on the device first.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    await tester.runAsync(
      () => container
          .read(babiesProvider.notifier)
          .add(
            Baby(
              id: 'x',
              name: 'Noah',
              gender: Gender.boy,
              birth: DateTime(2026, 10, 1),
              phases: const [
                Phase(start: Age.birth, frequency: Frequency.daily),
              ],
            ),
          ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cloud_download_outlined), findsNothing);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Bring back babies from Google Drive'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Disconnect Google Drive'), findsNothing);
  });
}

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

class _Cloud extends FakeCloud {
  int signOuts = 0;
  @override
  Future<void> signOut() async => signOuts++;
}

Baby _baby(StorageMode mode) => Baby(
  id: 'b',
  name: 'Luna',
  gender: Gender.girl,
  birth: DateTime(2026, 10, 10),
  phases: const [Phase(start: Age.birth, frequency: Frequency.daily)],
  storage: mode,
);

void main() {
  Future<(MemoryStore, _Cloud)> open(WidgetTester t, StorageMode mode) async {
    await t.binding.setSurfaceSize(const Size(420, 900));
    final store = MemoryStore();
    store.data['photos/b/00001_2026-10-10.jpg'] = Uint8List.fromList([1]);
    // already uploaded to Drive
    store.data['photos/b/.synced.json'] = Uint8List.fromList(
      utf8.encode('["00001_2026-10-10.jpg"]'),
    );
    store.data['calendar_status.json'] = Uint8List.fromList([2]);
    final cloud = _Cloud();
    final repo = MemoryRepository()..data = [_baby(mode)];
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWith((_) async => store),
          babyRepositoryProvider.overrideWith((_) async => repo),
          cloudProvider.overrideWithValue(cloud),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await t.pumpAndSettle();
    await t.tap(find.byType(PopupMenuButton<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('Log out'));
    await t.pumpAndSettle();
    return (store, cloud);
  }

  testWidgets('log out signs out, clears this device, keeps Drive', (t) async {
    final (store, cloud) = await open(t, StorageMode.googleDrive);
    expect(find.textContaining('Nothing is deleted'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Log out'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await t.pumpAndSettle();
    expect(cloud.signOuts, 1);
    expect(store.data, isEmpty);
    expect(find.text('Luna'), findsNothing);
    expect(find.text('I already registered my baby'), findsOneWidget);
  });

  testWidgets('babies only kept on this device block the log out', (t) async {
    final (store, cloud) = await open(t, StorageMode.appOnly);
    expect(find.text('Not yet'), findsOneWidget);
    expect(find.textContaining('only kept on this device'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Log out'), findsNothing);
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(cloud.signOuts, 0);
    expect(store.data, isNotEmpty);
    expect(find.text('Luna'), findsOneWidget);
  });
}

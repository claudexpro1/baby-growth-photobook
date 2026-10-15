import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/features/baby/baby_page.dart';
import 'package:baby_growth_photobook/features/baby/edit_baby_page.dart';
import 'package:baby_growth_photobook/notifications/calendar_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show MemoryRepository;
import 'photo_sync_test.dart' show FakeCloud;

Baby _baby(StorageMode mode, {bool reminders = true}) => Baby(
  id: 'a',
  name: 'Anna',
  gender: Gender.girl,
  birth: DateTime.now().subtract(const Duration(days: 4)),
  phases: const [Phase(start: Age.birth, frequency: Frequency.weekly)],
  storage: mode,
  reminder: ReminderSettings(enabled: reminders),
);

void main() {
  tearDown(() => useGoogleCalendar = false);

  Future<ProviderContainer> open(
    WidgetTester t,
    Baby baby, {
    Size size = const Size(400, 900),
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final repo = MemoryRepository()..data = [baby];
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWith((_) async => MemoryStore()),
          babyRepositoryProvider.overrideWith((_) async => repo),
          cloudProvider.overrideWithValue(FakeCloud()),
        ],
        child: const MaterialApp(home: BabyPage(babyId: 'a')),
      ),
    );
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 150)));
    await t.pumpAndSettle();
    return ProviderScope.containerOf(t.element(find.byType(BabyPage)));
  }

  testWidgets('Drive connected: one quiet line, details open in place', (
    t,
  ) async {
    await open(t, _baby(StorageMode.googleDrive));
    expect(find.text('Saved in Google Drive'), findsOneWidget);
    expect(find.text('Connect Google Drive'), findsNothing);
    expect(find.textContaining('steps left'), findsNothing);
    expect(find.textContaining('One step left'), findsNothing);
    // the long explanation and the buttons are hidden until opened
    expect(find.text('Sync now'), findsNothing);
    expect(find.textContaining('do not rename'), findsNothing);
    await t.tap(find.text('Saved in Google Drive'));
    await t.pumpAndSettle();
    expect(find.text('Sync now'), findsOneWidget);
    expect(find.text('Open in Drive'), findsOneWidget);
    expect(
      find.textContaining('do not rename, move or delete'),
      findsOneWidget,
    );
    expect(find.textContaining('added to the folder by hand'), findsNothing);
    expect(find.textContaining('by hand are not shown'), findsOneWidget);
  });

  testWidgets('reminders are a line on the page that opens in place', (
    t,
  ) async {
    await open(t, _baby(StorageMode.googleDrive));
    expect(find.textContaining('Reminders at'), findsOneWidget);
    expect(find.text('Time of day'), findsNothing);
    await t.tap(find.textContaining('Reminders at'));
    await t.pumpAndSettle();
    expect(find.text('Remind me to take a photo'), findsOneWidget);
    expect(find.text('Time of day'), findsOneWidget);
    expect(find.text('Change the photo schedule in Settings'), findsOneWidget);
  });

  testWidgets('switching reminders off on the page saves at once', (t) async {
    final c = await open(t, _baby(StorageMode.googleDrive));
    await t.tap(find.textContaining('Reminders at'));
    await t.pumpAndSettle();
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(c.read(babiesProvider).value!.single.reminder.enabled, isFalse);
    expect(find.text('Reminders are off'), findsOneWidget);
  });

  testWidgets('no Drive yet: the step is open with its button', (t) async {
    await open(t, _baby(StorageMode.appOnly));
    expect(find.text('One step left'), findsOneWidget);
    expect(find.text('Photos are only on this device'), findsOneWidget);
    expect(find.text('Connect Google Drive'), findsOneWidget);
  });

  testWidgets('Google sign-in lapsed: a Reconnect button, no pop-up', (
    t,
  ) async {
    final c = await open(t, _baby(StorageMode.googleDrive));
    c.read(driveReconnectProvider.notifier).set(true);
    await t.pumpAndSettle();
    expect(find.text('Reconnect to Google Drive'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reconnect'), findsOneWidget);
    expect(find.text('Saved in Google Drive'), findsNothing);
  });

  testWidgets('web: Calendar not set up yet is a visible step on the page', (
    t,
  ) async {
    useGoogleCalendar = true;
    await open(t, _baby(StorageMode.googleDrive));
    expect(find.text('One step left'), findsOneWidget);
    expect(find.text('Add reminders to your Google Calendar'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add reminders'), findsOneWidget);
  });

  testWidgets('web: Drive and Calendar both missing: two steps', (t) async {
    useGoogleCalendar = true;
    await open(t, _baby(StorageMode.appOnly));
    expect(find.text('Two steps left'), findsOneWidget);
  });

  testWidgets('a gear next to the three dots opens Settings', (t) async {
    await open(t, _baby(StorageMode.googleDrive));
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('More'), findsOneWidget);
    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    expect(find.byType(EditBabyPage), findsOneWidget);
  });
}

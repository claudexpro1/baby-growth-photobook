import 'dart:typed_data';

import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/photo_library.dart';
import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/features/baby/edit_baby_page.dart';
import 'package:baby_growth_photobook/notifications/calendar_status.dart';
import 'package:baby_growth_photobook/notifications/google_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:http/testing.dart';

import 'app_flow_test.dart' show MemoryRepository;
import 'google_calendar_test.dart' show FakeCalendarServer;

class _Gate extends ConsumerWidget {
  const _Gate();
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(babiesProvider).hasValue
      ? const EditBabyPage(babyId: 'a')
      : const SizedBox();
}

void main() {
  final baby = Baby(
    id: 'a',
    name: 'Anna',
    gender: Gender.girl,
    birth: DateTime(2026, 10, 10, 8, 30),
    birthPlace: 'Athens',
    phases: const [Phase(start: Age.birth, frequency: Frequency.weekly)],
    reminder: const ReminderSettings(enabled: false),
  );

  Future<(MemoryRepository, ProviderContainer)> open(
    WidgetTester tester, {
    bool oldPhoto = false,
    Baby? start,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 3000));
    final repo = MemoryRepository()..data = [start ?? baby];
    final store = MemoryStore();
    if (oldPhoto) {
      await tester.runAsync(
        () => PhotoLibrary(
          store,
          'photos/a',
        ).add(Uint8List.fromList([1, 2, 3]), DateTime(2026, 10, 6)),
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWith((_) async => store),
          babyRepositoryProvider.overrideWith((_) async => repo),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    Navigator.of(c)
                        .push(MaterialPageRoute(builder: (_) => const _Gate())),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.tap(find.text('open'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    return (
      repo,
      ProviderScope.containerOf(tester.element(find.byType(EditBabyPage))),
    );
  }

  testWidgets('Settings shows and saves name, place and colours', (
    tester,
  ) async {
    final (repo, _) = await open(tester);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Athens'), findsOneWidget);
    expect(find.text('Birth date'), findsOneWidget);
    expect(find.text('Birth time'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Anna'), 'Anni');
    await tester.enterText(find.widgetWithText(TextField, 'Athens'), 'Patras');
    await tester.tap(find.text('Boy'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(repo.data.single.name, 'Anni');
    expect(repo.data.single.birthPlace, 'Patras');
    expect(repo.data.single.gender, Gender.boy);
    expect(repo.data.single.birth, baby.birth); // no confirmation needed
    expect(find.textContaining('Saved'), findsOneWidget);
  });

  testWidgets('changing the birth date asks first and warns about old photos', (
    tester,
  ) async {
    final (repo, _) = await open(tester, oldPhoto: true);
    await tester.tap(find.text('Birth date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('8')); // Oct 8: the Oct 6 photo is now earlier
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Change the birth date?'), findsOneWidget);
    expect(find.textContaining('1 photo is dated before'), findsOneWidget);

    // Cancel: nothing changes.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.data.single.birth, baby.birth);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change birth date'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(repo.data.single.birth, DateTime(2026, 10, 8, 8, 30));
  });

  testWidgets('Save also updates the linked Google Calendar', (tester) async {
    final server = FakeCalendarServer()
      ..calendarExists = true
      ..title = 'Baby Photobook - Anna';
    useGoogleCalendar = true;
    GoogleCalendarReminders.instance.apiFactory = ({required bool prompt}) =>
        cal.CalendarApi(MockClient((r) => server.handle(r)));
    addTearDown(() {
      useGoogleCalendar = false;
      GoogleCalendarReminders.instance.apiFactory = null;
    });
    final linked = baby.copyWith(
      googleCalendarId: 'cal1',
      reminder: const ReminderSettings(enabled: true),
    );
    final (repo, _) = await open(tester, start: linked);
    await tester.enterText(find.widgetWithText(TextField, 'Anna'), 'Anni');
    await tester.pump();
    // unsaved edits: the box asks for Save first
    expect(find.textContaining('until you save'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(repo.data.single.name, 'Anni');
    expect(server.title, 'Baby Photobook - Anni');
    expect(server.events, isNotEmpty);
    expect(find.textContaining('Done:'), findsOneWidget);
  });

  testWidgets('Save and update calendar saves the edits first and stays', (
    tester,
  ) async {
    final server = FakeCalendarServer()
      ..calendarExists = true
      ..title = 'Baby Photobook - Anna';
    useGoogleCalendar = true;
    GoogleCalendarReminders.instance.apiFactory = ({required bool prompt}) =>
        cal.CalendarApi(MockClient((r) => server.handle(r)));
    addTearDown(() {
      useGoogleCalendar = false;
      GoogleCalendarReminders.instance.apiFactory = null;
    });
    final linked = baby.copyWith(
      googleCalendarId: 'cal1',
      reminder: const ReminderSettings(enabled: true),
    );
    final (repo, _) = await open(tester, start: linked);
    expect(find.text('Save and update calendar'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Anna'), 'Anni');
    await tester.pump();
    await tester.tap(find.text('Save and update calendar'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(repo.data.single.name, 'Anni');
    expect(server.title, 'Baby Photobook - Anni');
    expect(find.byType(EditBabyPage), findsOneWidget); // still here
    expect(find.text('Save and update calendar'), findsNothing); // saved now
    expect(
      find.textContaining('Reminders are in Calendar until'),
      findsOneWidget,
    );
  });
}

import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/features/baby/edit_baby_page.dart';
import 'package:baby_growth_photobook/features/home/home_page.dart';
import 'package:baby_growth_photobook/notifications/calendar_status.dart';
import 'package:baby_growth_photobook/notifications/google_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:http/testing.dart';

import 'app_flow_test.dart' show MemoryRepository;
import 'google_calendar_test.dart' show FakeCalendarServer;

Baby _baby({String? calendarId, bool reminders = true}) => Baby(
  id: 'abc1',
  name: 'Luna',
  gender: Gender.girl,
  birth: DateTime(2026, 10, 10),
  phases: const [Phase(start: Age.birth, frequency: Frequency.daily)],
  reminder: ReminderSettings(enabled: reminders, hour: 9),
  googleCalendarId: calendarId,
);

void main() {
  late FakeCalendarServer server;
  final service = GoogleCalendarReminders.instance;

  setUp(() {
    useGoogleCalendar = true;
    server = FakeCalendarServer();
    service.apiFactory = ({required bool prompt}) =>
        cal.CalendarApi(MockClient((r) => server.handle(r)));
  });
  tearDown(() {
    useGoogleCalendar = false;
    service.apiFactory = null;
  });

  Future<void> open(WidgetTester tester, Baby baby, Widget home) async {
    await tester.binding.setSurfaceSize(const Size(420, 2600));
    final repo = MemoryRepository()..data = [baby];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWith((_) async => MemoryStore()),
          babyRepositoryProvider.overrideWith((_) async => repo),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
  }

  test('check: calendar deleted on the server is reported missing', () async {
    final b = _baby();
    await service.sync(b, DateTime.now(), {});
    final ok = await service.check(
      b.copyWith(googleCalendarId: 'cal1'),
      DateTime.now(),
    );
    expect(ok.state, CalendarState.ok);
    expect(ok.count, GoogleCalendarReminders.windowSize);
    expect(ok.next, isNotNull);

    server.calendarExists = false;
    final gone = await service.check(
      b.copyWith(googleCalendarId: 'cal1'),
      DateTime.now(),
    );
    expect(gone.state, CalendarState.missing);
  });

  test('badge words and colours', () {
    expect(calendarBadge(_baby(reminders: false), null).label, 'Calendar off');
    expect(calendarBadge(_baby(), null).label, 'Not in Calendar yet');
    expect(calendarBadge(_baby(calendarId: 'cal1'), null).label, 'Tap to check');
    final missing = CalendarCheck(
      state: CalendarState.missing,
      calendarId: 'cal1',
      checkedAt: DateTime.now(),
    );
    expect(
      calendarBadge(_baby(calendarId: 'cal1'), missing).tone,
      BadgeTone.bad,
    );
    final good = CalendarCheck(
      state: CalendarState.ok,
      calendarId: 'cal1',
      checkedAt: DateTime.now(),
      count: 60,
    );
    final b = calendarBadge(_baby(calendarId: 'cal1'), good);
    expect(b.label, 'Calendar ✓');
    expect(b.detail, contains('60 upcoming'));
  });

  testWidgets('list card turns red when the calendar was deleted', (
    tester,
  ) async {
    await service.sync(_baby(), DateTime.now(), {});
    server.calendarExists = false; // the parent deleted it by hand
    await open(tester, _baby(calendarId: 'cal1'), const HomePage());
    expect(find.text('Calendar missing'), findsOneWidget);
  });

  testWidgets('list card shows Calendar ✓ when it is there', (tester) async {
    await service.sync(_baby(), DateTime.now(), {});
    await open(tester, _baby(calendarId: 'cal1'), const HomePage());
    expect(find.text('Calendar ✓'), findsOneWidget);
  });

  testWidgets('list card without a calendar says so and never calls Google', (
    tester,
  ) async {
    await open(tester, _baby(), const HomePage());
    expect(find.text('Not in Calendar yet'), findsOneWidget);
    expect(server.calls, 0);
  });

  testWidgets('Settings: missing calendar -> Fix it -> new calendar, green', (
    tester,
  ) async {
    await service.sync(_baby(), DateTime.now(), {});
    server.calendarExists = false;
    server.events.clear();
    await open(
      tester,
      _baby(calendarId: 'cal1'),
      const _Gate(EditBabyPage(babyId: 'abc1')),
    );
    expect(find.textContaining('Not found in your Google Calendar'), findsOneWidget);

    await tester.tap(find.text('Fix it'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(server.calendarsCreated, 2);
    expect(find.textContaining('Done: 60 reminders'), findsWidgets);
    expect(find.textContaining('60 upcoming reminders'), findsOneWidget);
  });

  testWidgets('Update calendar never stays silent when writes are lost', (
    tester,
  ) async {
    await service.sync(_baby(), DateTime.now(), {});
    server.events.clear();
    server.dropWrites = true;
    await open(
      tester,
      _baby(calendarId: 'cal1'),
      const _Gate(EditBabyPage(babyId: 'abc1')),
    );
    await tester.tap(find.text('Update calendar'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('only holds 0 of 60'), findsWidgets);
    expect(find.textContaining('Done:'), findsNothing);
  });
}

/// Shows [child] once the babies have loaded (Settings expects them).
class _Gate extends ConsumerWidget {
  const _Gate(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(babiesProvider).hasValue ? child : const SizedBox();
}

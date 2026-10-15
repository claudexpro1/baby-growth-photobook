import 'dart:convert';

import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/notifications/google_calendar.dart';
import 'package:baby_growth_photobook/notifications/calendar_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A tiny pretend Google Calendar server.
class FakeCalendarServer {
  final events = <String, Map<String, dynamic>>{};
  final deletedIds = <String>{};
  bool calendarExists = false;

  /// A calendar deleted by hand: gone from the user's list, yet `get` and
  /// `events` may still answer for a while.
  bool ghost = false;

  /// Real Google answers 401 to calendarList for the narrow app-created scope.
  bool calendarListRefused = false;
  int calendarsCreated = 0;
  int calls = 0;
  String? title; // set by a create or a rename

  /// Pretend writes succeed but nothing is kept (a hidden/broken calendar).
  bool dropWrites = false;

  Future<http.Response> handle(http.Request r) async {
    calls++;
    final path = r.url.path;
    http.Response ok(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
    http.Response err(int code) => http.Response(
      jsonEncode({
        'error': {'code': code, 'message': 'x'},
      }),
      code,
      headers: {'content-type': 'application/json'},
    );
    if (path.endsWith('/calendarList/cal1') && r.method == 'GET') {
      if (calendarListRefused) return err(401);
      return calendarExists && !ghost
          ? ok({'id': 'cal1', 'summary': title})
          : err(404);
    }
    if (path.endsWith('/calendars') && r.method == 'POST') {
      calendarExists = true;
      ghost = false;
      calendarsCreated++;
      title = (jsonDecode(r.body) as Map)['summary'] as String?;
      return ok({'id': 'cal1', 'summary': title});
    }
    if (path.endsWith('/calendars/cal1') && r.method == 'GET') {
      return calendarExists ? ok({'id': 'cal1', 'summary': title}) : err(404);
    }
    if (path.endsWith('/calendars/cal1') && r.method == 'PATCH') {
      title = (jsonDecode(r.body) as Map)['summary'] as String?;
      return ok({'id': 'cal1', 'summary': title});
    }
    if (path.endsWith('/calendars/cal1') && r.method == 'DELETE') {
      calendarExists = false;
      return ok({});
    }
    if (path.endsWith('/calendars/cal1/events') && r.method == 'GET') {
      if (!calendarExists) return err(404);
      return ok({'items': events.values.toList()});
    }
    if (path.endsWith('/calendars/cal1/events') && r.method == 'POST') {
      final e = jsonDecode(r.body) as Map<String, dynamic>;
      if (!dropWrites) events[e['id'] as String] = e;
      return ok(e);
    }
    final m = RegExp(r'/calendars/cal1/events/(.+)$').firstMatch(path);
    if (m != null) {
      final id = m[1]!;
      if (r.method == 'PUT') {
        if (!events.containsKey(id)) return err(404);
        events[id] = jsonDecode(r.body) as Map<String, dynamic>;
        return ok(events[id]!);
      }
      if (r.method == 'DELETE') {
        if (events.remove(id) == null) return err(404);
        deletedIds.add(id);
        return ok({});
      }
    }
    return err(400);
  }
}

void main() {
  late FakeCalendarServer server;
  final service = GoogleCalendarReminders.instance;
  final now = DateTime(2026, 10, 11, 12);
  Baby baby({bool reminders = true, String? calendarId}) => Baby(
    id: 'abc1',
    name: 'Luna',
    gender: Gender.girl,
    birth: DateTime(2026, 10, 10),
    phases: const [Phase(start: Age.birth, frequency: Frequency.daily)],
    reminder: ReminderSettings(enabled: reminders, hour: 9, minute: 30),
    googleCalendarId: calendarId,
  );

  setUp(() {
    server = FakeCalendarServer();
    service.apiFactory = ({required bool prompt}) =>
        cal.CalendarApi(MockClient((r) => server.handle(r)));
  });
  tearDown(() => service.apiFactory = null);

  test('creates a calendar and the upcoming reminders with popups', () async {
    final id = await service.sync(baby(), now, {});
    expect(id, 'cal1');
    expect(server.events.length, GoogleCalendarReminders.windowSize);
    final e = server.events.values.first;
    expect(e['summary'], "Time for Luna's photo");
    expect(e['reminders']['useDefault'], false);
    expect(e['reminders']['overrides'][0], {'method': 'popup', 'minutes': 0});
  });

  test('every reminder carries the link that opens the app', () async {
    await service.sync(baby(), now, {});
    final e = server.events.values.first;
    expect(
      e['description'],
      contains('Open Baby Photobook: ${GoogleCalendarReminders.appUrl}'),
    );
    expect(e['source'], {
      'title': 'Baby Photobook',
      'url': GoogleCalendarReminders.appUrl,
    });
    expect(GoogleCalendarReminders.appUrl, startsWith('https://'));
  });

  test('syncing again updates instead of duplicating', () async {
    await service.sync(baby(), now, {});
    await service.sync(baby(calendarId: 'cal1'), now, {});
    expect(server.calendarsCreated, 1);
    expect(server.events.length, GoogleCalendarReminders.windowSize);
  });

  test('a day with a photo loses its reminder', () async {
    await service.sync(baby(), now, {});
    final tomorrow = DateTime.utc(2026, 10, 12);
    final id = GoogleCalendarReminders.eventId(baby(), tomorrow);
    expect(server.events.containsKey(id), isTrue);
    await service.sync(baby(calendarId: 'cal1'), now, {tomorrow});
    expect(server.events.containsKey(id), isFalse);
  });

  test('reminders off empties the calendar', () async {
    await service.sync(baby(), now, {});
    await service.sync(baby(reminders: false, calendarId: 'cal1'), now, {});
    expect(server.events, isEmpty);
  });

  test('a deleted calendar is created again', () async {
    await service.sync(baby(), now, {});
    server.calendarExists = false;
    server.events.clear();
    await service.sync(baby(calendarId: 'cal1'), now, {});
    expect(server.calendarsCreated, 2);
    expect(server.events, isNotEmpty);
  });

  test(
    'a calendar gone from the list counts as missing even if get answers',
    () async {
      final b = baby();
      await service.sync(b, now, {});
      server.ghost = true;
      final check = await service.check(baby(calendarId: 'cal1'), now);
      expect(check.state, CalendarState.missing);
      // and syncing makes a new one instead of writing into the ghost
      await service.sync(baby(calendarId: 'cal1'), now, {});
      expect(server.calendarsCreated, 2);
    },
  );

  test('event ids only use characters Google accepts', () {
    final id = GoogleCalendarReminders.eventId(
      baby(),
      DateTime.utc(2026, 10, 12),
    );
    expect(RegExp(r'^[a-v0-9]{5,}$').hasMatch(id), isTrue);
  });

  test('a renamed baby renames the calendar and the reminders', () async {
    await service.sync(baby(), now, {});
    expect(server.title, 'Baby Photobook - Luna');
    final renamed = baby(calendarId: 'cal1').copyWith(name: 'Lulu');
    await service.sync(renamed, now, {});
    expect(server.title, 'Baby Photobook - Lulu');
    expect(server.calendarsCreated, 1);
    expect(server.events.values.first['summary'], "Time for Lulu's photo");
  });

  test(
    'a refused calendar-list question does not break check or sync',
    () async {
      server.calendarListRefused = true;
      final id = await service.sync(baby(), now, {});
      expect(id, 'cal1');
      final check = await service.check(baby(calendarId: 'cal1'), now);
      expect(check.state, CalendarState.ok);
      expect(check.count, GoogleCalendarReminders.windowSize);
      // a deleted calendar is still noticed through the other calls
      server.calendarExists = false;
      final gone = await service.check(baby(calendarId: 'cal1'), now);
      expect(gone.state, CalendarState.missing);
    },
  );
}

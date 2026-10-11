import 'dart:convert';

import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/notifications/google_calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A tiny pretend Google Calendar server.
class FakeCalendarServer {
  final events = <String, Map<String, dynamic>>{};
  final deletedIds = <String>{};
  bool calendarExists = false;
  int calendarsCreated = 0;

  Future<http.Response> handle(http.Request r) async {
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
    if (path.endsWith('/calendars') && r.method == 'POST') {
      calendarExists = true;
      calendarsCreated++;
      return ok({'id': 'cal1'});
    }
    if (path.endsWith('/calendars/cal1') && r.method == 'GET') {
      return calendarExists ? ok({'id': 'cal1'}) : err(404);
    }
    if (path.endsWith('/calendars/cal1') && r.method == 'DELETE') {
      calendarExists = false;
      return ok({});
    }
    if (path.endsWith('/calendars/cal1/events') && r.method == 'GET') {
      return ok({'items': events.values.toList()});
    }
    if (path.endsWith('/calendars/cal1/events') && r.method == 'POST') {
      final e = jsonDecode(r.body) as Map<String, dynamic>;
      events[e['id'] as String] = e;
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

  test('event ids only use characters Google accepts', () {
    final id = GoogleCalendarReminders.eventId(
      baby(),
      DateTime.utc(2026, 10, 12),
    );
    expect(RegExp(r'^[a-v0-9]{5,}$').hasMatch(id), isTrue);
  });
}

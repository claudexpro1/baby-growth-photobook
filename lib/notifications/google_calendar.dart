import 'package:googleapis/calendar/v3.dart' as cal;

import '../data/google_auth.dart';
import '../domain/age_label.dart';
import '../domain/baby.dart';
import 'reminder_planner.dart';

/// Photo reminders as events in the user's own Google Calendar.
///
/// Uses the narrow `calendar.app.created` permission: the app can create its
/// own calendar ("Baby Photobook - Luna", for example) and the events inside it, and
/// nothing else. It cannot read or change the user's other calendars. The
/// phone's Calendar app then shows the notifications, on every device.
class GoogleCalendarReminders {
  GoogleCalendarReminders._();
  static final GoogleCalendarReminders instance = GoogleCalendarReminders._();

  static const scopes = [cal.CalendarApi.calendarAppCreatedScope];

  /// How many upcoming reminders are kept in the calendar.
  static const windowSize = 60;

  /// Asks Google for permission (needs a user tap on the web).
  Future<void> connect() => GoogleAuth.authorize(scopes);

  /// Tests plug in a fake calendar server here.
  cal.CalendarApi Function({required bool prompt})? apiFactory;

  cal.CalendarApi _api({required bool prompt}) =>
      apiFactory?.call(prompt: prompt) ??
      cal.CalendarApi(
        GoogleAuthClient(() async {
          final h = await GoogleAuth.headers(scopes, prompt: prompt);
          if (h == null) throw const CalendarNotConnected();
          return h;
        }),
      );

  /// Brings the calendar in line with the baby's schedule: creates it if
  /// needed, adds the upcoming reminders, removes ones that are no longer
  /// wanted (reminders off, photo already taken, schedule changed).
  /// Returns the calendar id. With [prompt] false nothing is shown and
  /// [CalendarNotConnected] is thrown if the user has not allowed it yet.
  Future<String> sync(
    Baby baby,
    DateTime now,
    Set<DateTime> photoDates, {
    bool prompt = true,
  }) async {
    final api = _api(prompt: prompt);
    final calendarId = await _ensureCalendar(api, baby);
    final plan = baby.reminder.enabled
        ? planReminders(baby, now, photoDates: photoDates, max: windowSize)
        : const <PlannedReminder>[];
    final wanted = <String, PlannedReminder>{
      for (final r in plan) eventId(baby, r.photoDate): r,
    };

    // Remove upcoming events we no longer want.
    String? token;
    do {
      final existing = await api.events.list(
        calendarId,
        timeMin: now.toUtc(),
        singleEvents: true,
        maxResults: 250,
        pageToken: token,
      );
      for (final e in existing.items ?? <cal.Event>[]) {
        if (e.id != null && !wanted.containsKey(e.id)) {
          await _ignoreGone(() => api.events.delete(calendarId, e.id!));
        }
      }
      token = existing.nextPageToken;
    } while (token != null);

    // Add or refresh the wanted ones.
    for (final entry in wanted.entries) {
      final event = _event(baby, entry.key, entry.value);
      try {
        await api.events.update(event, calendarId, entry.key);
      } on cal.DetailedApiRequestError catch (e) {
        if (e.status != 404) rethrow;
        try {
          await api.events.insert(event, calendarId);
        } on cal.DetailedApiRequestError catch (e) {
          // The id was used before (event was deleted): bring it back.
          if (e.status != 409) rethrow;
          await api.events.update(event, calendarId, entry.key);
        }
      }
    }
    return calendarId;
  }

  /// Deletes the baby's calendar (for example when the baby is removed).
  Future<void> remove(Baby baby, {bool prompt = false}) async {
    final id = baby.googleCalendarId;
    if (id == null) return;
    final api = _api(prompt: prompt);
    await _ignoreGone(() => api.calendars.delete(id));
  }

  Future<String> _ensureCalendar(cal.CalendarApi api, Baby baby) async {
    final existing = baby.googleCalendarId;
    if (existing != null) {
      try {
        await api.calendars.get(existing);
        return existing;
      } on cal.DetailedApiRequestError catch (e) {
        if (e.status != 404 && e.status != 410) rethrow;
      }
    }
    final created = await api.calendars.insert(
      cal.Calendar(
        summary: 'Baby Photobook - ${baby.name}',
        description:
            "Photo reminders for ${baby.name}. Made by Baby Photobook.",
        timeZone: 'UTC',
      ),
    );
    return created.id!;
  }

  /// Stable id per baby and day (base32hex: letters a-v and digits), so the
  /// same reminder is updated, never duplicated.
  static String eventId(Baby baby, DateTime photoDate) {
    String two(int n) => n.toString().padLeft(2, '0');
    final safe = baby.id.toLowerCase().replaceAll(RegExp('[^0-9a-v]'), '');
    return 'bp${safe}d${photoDate.year}${two(photoDate.month)}${two(photoDate.day)}';
  }

  cal.Event _event(Baby baby, String id, PlannedReminder r) {
    // Local time with its own UTC offset, so it fires at the chosen hour.
    final start = r.when;
    final end = start.add(const Duration(minutes: 15));
    return cal.Event(
      id: id,
      status: 'confirmed',
      summary: "Time for ${baby.name}'s photo",
      description: ageLabel(baby.birth, r.photoDate),
      start: cal.EventDateTime(dateTime: _withOffset(start)),
      end: cal.EventDateTime(dateTime: _withOffset(end)),
      reminders: cal.EventReminders(
        useDefault: false,
        overrides: [cal.EventReminder(method: 'popup', minutes: 0)],
      ),
    );
  }

  /// A DateTime that the API serialises with the right offset: the Calendar
  /// API reads the instant, so we pass the UTC value of the local time.
  DateTime _withOffset(DateTime local) => local.toUtc();

  Future<void> _ignoreGone(Future<void> Function() run) async {
    try {
      await run();
    } on cal.DetailedApiRequestError catch (e) {
      if (e.status != 404 && e.status != 410) rethrow;
    }
  }
}

/// The user has not allowed Calendar access (yet) in this session.
class CalendarNotConnected implements Exception {
  const CalendarNotConnected();
  @override
  String toString() => 'Google Calendar is not connected';
}

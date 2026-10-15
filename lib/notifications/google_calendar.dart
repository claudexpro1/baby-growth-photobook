import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as cal;

import '../data/google_auth.dart';
import '../domain/age_label.dart';
import '../domain/baby.dart';
import 'calendar_status.dart';
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

  /// Where the app lives. Every reminder carries this link, so tapping the
  /// notification or the event in Google Calendar opens the app.
  static const appUrl = 'https://claudexpro1.github.io/baby-growth-photobook/';

  /// The link to put in events: the address the app is running from when that
  /// is a real web address, otherwise [appUrl].
  static String get appLink {
    if (kIsWeb && Uri.base.scheme.startsWith('http')) {
      return Uri.base
          .replace(query: '', fragment: '')
          .toString()
          .replaceAll(RegExp(r'\?$'), '');
    }
    return appUrl;
  }

  /// How many upcoming reminders are kept in the calendar.
  static const windowSize = 60;

  /// Asks Google for permission (needs a user tap on the web).
  Future<void> connect() async {
    if (apiFactory != null) return; // tests: no Google window
    await GoogleAuth.authorize(scopes);
  }

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

  /// How many reminders [sync] should leave in the calendar.
  static int expectedCount(Baby baby, DateTime now, Set<DateTime> photoDates) =>
      baby.reminder.enabled
      ? planReminders(baby, now, photoDates: photoDates, max: windowSize).length
      : 0;

  /// Is the calendar still in the user's calendar list? A calendar deleted by
  /// hand can keep answering `calendars.get` and `events.list` for a while,
  /// but it is gone from the list. Throws a 404 when it is gone.
  ///
  /// Google may refuse this question for an app that only holds the narrow
  /// "calendars this app created" permission (401/403). That says nothing
  /// about the calendar, so then the other checks decide.
  Future<void> _requireInList(cal.CalendarApi api, String id) async {
    try {
      final entry = await api.calendarList.get(id);
      if (entry.deleted == true) {
        throw cal.DetailedApiRequestError(404, 'Calendar was deleted');
      }
    } on cal.DetailedApiRequestError catch (e) {
      if (e.status == 401 || e.status == 403) return;
      rethrow;
    }
  }

  /// Looks in Google Calendar: does the baby's calendar still exist, and how
  /// many upcoming reminders does it hold? Never creates anything. Throws
  /// [CalendarNotConnected] when [prompt] is false and Google needs a tap.
  Future<CalendarCheck> check(
    Baby baby,
    DateTime now, {
    bool prompt = false,
  }) async {
    final id = baby.googleCalendarId!;
    final api = _api(prompt: prompt);
    var count = 0;
    DateTime? next;
    DateTime? last;
    try {
      await _requireInList(api, id);
      await api.calendars.get(id);
      String? token;
      do {
        final page = await api.events.list(
          id,
          timeMin: now.toUtc(),
          singleEvents: true,
          maxResults: 250,
          pageToken: token,
        );
        for (final e in page.items ?? <cal.Event>[]) {
          if (e.status == 'cancelled') continue;
          count++;
          final start = e.start?.dateTime?.toLocal();
          if (start != null && (next == null || start.isBefore(next))) {
            next = start;
          }
          if (start != null && (last == null || start.isAfter(last))) {
            last = start;
          }
        }
        token = page.nextPageToken;
      } while (token != null);
    } on cal.DetailedApiRequestError catch (e) {
      if (e.status != 404 && e.status != 410) rethrow;
      return CalendarCheck(
        state: CalendarState.missing,
        calendarId: id,
        checkedAt: now,
      );
    }
    return CalendarCheck(
      state: CalendarState.ok,
      calendarId: id,
      checkedAt: now,
      count: count,
      next: next,
      lastReminder: last,
    );
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
        await _requireInList(api, existing);
        final c = await api.calendars.get(existing);
        // A calendar deleted by hand can still answer `get`; its events cannot.
        await api.events.list(existing, maxResults: 1);
        final title = calendarTitle(baby);
        if (c.summary != null && c.summary != title) {
          // The baby was renamed: rename the calendar too.
          await api.calendars.patch(cal.Calendar(summary: title), existing);
        }
        return existing;
      } on cal.DetailedApiRequestError catch (e) {
        if (e.status != 404 && e.status != 410) rethrow;
      }
    }
    final created = await api.calendars.insert(
      cal.Calendar(
        summary: calendarTitle(baby),
        description:
            "Photo reminders for ${baby.name}. Made by Baby Photobook.",
        timeZone: 'UTC',
      ),
    );
    return created.id!;
  }

  /// The calendar's name in Google Calendar.
  static String calendarTitle(Baby baby) => 'Baby Photobook - ${baby.name}';

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
      description:
          '${ageLabel(baby.birth, r.photoDate)}\n\nOpen Baby Photobook: $appLink',
      source: cal.EventSource(title: 'Baby Photobook', url: appLink),
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

/// Says what went wrong with Google Calendar, in words a parent (or the app's
/// owner) can act on. "Allow access" is only said when that is really the
/// problem.
String calendarErrorMessage(Object e) {
  if (e is CalendarMismatch) {
    return 'Google Calendar only holds ${e.found} of ${e.expected} reminders. '
        'Tap again; if it stays this way, check the "Baby Photobook" calendar is ticked in Google Calendar.';
  }
  if (e is GoogleReauthFailed) {
    return e.cause is CalendarNotConnected || e.cause is GoogleSignInException
        ? calendarErrorMessage(e.cause)
        : 'Google no longer accepts the saved sign-in and a new one could not '
              'be started (${e.cause}). Allow pop-ups for this site, then tap again.';
  }
  if (e is CalendarNotConnected) {
    return 'Google Calendar is not allowed yet. Tap again and allow Calendar access.';
  }
  if (e is GoogleSignInException) {
    return switch (e.code) {
      GoogleSignInExceptionCode.uiUnavailable =>
        "Your browser blocked Google's sign-in window. Allow pop-ups for this site "
            '(look for the blocked-pop-up icon at the right end of the address bar), then tap again.',
      GoogleSignInExceptionCode.canceled => "The Google window was closed before you allowed Calendar access. Tap again and choose Allow.",
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google sign-in is not set up correctly for this app '
            '(${e.description ?? e.code.name}). The app owner needs to check the Google Cloud setup.',
      _ => 'Google sign-in did not finish (${e.code.name}). Please try again.',
    };
  }
  if (e is cal.DetailedApiRequestError) {
    final text = '${e.message} ${e.errors.map((x) => x.reason).join(' ')}';
    final off =
        text.contains('accessNotConfigured') ||
        text.contains('has not been used') ||
        text.contains('is disabled');
    if (e.status == 403 && off) {
      return 'The Google Calendar API is not switched on for this app in Google Cloud. '
          'The app owner needs to enable it (Google Cloud > APIs & Services > Google Calendar API).';
    }
    if (e.status == 403) {
      return 'Google did not give this app Calendar access (error 403: ${e.message ?? 'forbidden'}). '
          'Tap again and tick the Calendar box when Google asks.';
    }
    if (e.status == 401) {
      return 'Your Google sign-in has expired. Tap again and allow Calendar access. '
          '(Google refused: ${GoogleAuth.lastRequest})';
    }
    return 'Google Calendar answered with an error (${e.status}: ${e.message ?? 'unknown'}).';
  }
  return 'Could not reach Google Calendar (${e.runtimeType}). Check your connection and try again.';
}

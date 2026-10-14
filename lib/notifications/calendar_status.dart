import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../domain/baby.dart';

/// True where reminders live in Google Calendar (the web app). Tests switch
/// it on to exercise that screen on the VM.
bool useGoogleCalendar = kIsWeb;

/// What the last look at a baby's Google Calendar found.
enum CalendarState { ok, missing }

/// The result of checking that a baby's calendar really exists in the user's
/// Google Calendar. Kept on the device so lists can show it instantly.
class CalendarCheck {
  const CalendarCheck({
    required this.state,
    required this.calendarId,
    required this.checkedAt,
    this.count = 0,
    this.next,
    this.lastReminder,
  });

  final CalendarState state;
  final String calendarId;
  final DateTime checkedAt;

  /// Upcoming reminders found in the calendar.
  final int count;

  /// When the next reminder fires.
  final DateTime? next;

  /// When the last reminder now in the calendar fires.
  final DateTime? lastReminder;

  bool get exists => state == CalendarState.ok;

  Map<String, dynamic> toJson() => {
    'state': state.name,
    'calendarId': calendarId,
    'checkedAt': checkedAt.toIso8601String(),
    'count': count,
    if (next != null) 'next': next!.toIso8601String(),
    if (lastReminder != null) 'last': lastReminder!.toIso8601String(),
  };

  factory CalendarCheck.fromJson(Map<String, dynamic> j) => CalendarCheck(
    state: CalendarState.values.byName(j['state'] as String),
    calendarId: j['calendarId'] as String,
    checkedAt: DateTime.parse(j['checkedAt'] as String),
    count: j['count'] as int? ?? 0,
    next: j['next'] == null ? null : DateTime.parse(j['next'] as String),
    lastReminder: j['last'] == null
        ? null
        : DateTime.parse(j['last'] as String),
  );

  static Map<String, CalendarCheck> decodeAll(String source) {
    final j = jsonDecode(source) as Map<String, dynamic>;
    return {
      for (final e in j.entries)
        e.key: CalendarCheck.fromJson(e.value as Map<String, dynamic>),
    };
  }

  static String encodeAll(Map<String, CalendarCheck> all) =>
      jsonEncode({for (final e in all.entries) e.key: e.value.toJson()});
}

enum BadgeTone { good, bad, warn, quiet }

/// What to show for one baby: the same words and colours on the list and in
/// Settings.
class CalendarBadge {
  const CalendarBadge(this.label, this.tone, this.detail);
  final String label;
  final BadgeTone tone;

  /// A longer sentence for the Settings box.
  final String detail;
}

/// Works out the badge from the baby and the last known check.
CalendarBadge calendarBadge(Baby baby, CalendarCheck? last) {
  if (!baby.reminder.enabled) {
    return const CalendarBadge(
      'Calendar off',
      BadgeTone.quiet,
      'Reminders are off.',
    );
  }
  if (baby.googleCalendarId == null) {
    return const CalendarBadge(
      'Not in Calendar yet',
      BadgeTone.quiet,
      'Not in your Google Calendar yet, so nothing will remind you.',
    );
  }
  if (last == null || last.calendarId != baby.googleCalendarId) {
    return const CalendarBadge(
      'Tap to check',
      BadgeTone.warn,
      'Not checked yet in this session.',
    );
  }
  if (last.state == CalendarState.missing) {
    return const CalendarBadge(
      'Calendar missing',
      BadgeTone.bad,
      'Not found in your Google Calendar. It may have been deleted.',
    );
  }
  return CalendarBadge(
    'Calendar ✓',
    BadgeTone.good,
    'In your Google Calendar "Baby Photobook - ${baby.name}": '
        '${last.count} upcoming reminder${last.count == 1 ? '' : 's'}.',
  );
}

/// Link that opens the calendar's settings in Google Calendar, where a hidden
/// calendar can be ticked.
String openCalendarUrl(String calendarId) {
  final cid = base64Url.encode(utf8.encode(calendarId)).replaceAll('=', '');
  return 'https://calendar.google.com/calendar/u/0/r?cid=$cid';
}

/// Fewer reminders were found in the calendar than the app wrote.
class CalendarMismatch implements Exception {
  const CalendarMismatch(this.expected, this.found);
  final int expected;
  final int found;
  @override
  String toString() =>
      'Google Calendar holds $found of $expected reminders after writing.';
}

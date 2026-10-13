import '../domain/baby.dart';

/// One planned reminder.
class PlannedReminder {
  const PlannedReminder(this.when, this.photoDate);

  /// Local moment the notification should fire.
  final DateTime when;

  /// The schedule date this reminder is for (date-only, UTC).
  final DateTime photoDate;
}

/// Works out the next reminders for [baby]. Pure function so it is easy to test.
///
/// iOS only keeps 64 pending local notifications, so we plan a limited rolling
/// window ([max]) and re-plan every time the app opens or a photo is added.
/// Dates that already have a photo are skipped.
List<PlannedReminder> planReminders(
  Baby baby,
  DateTime now, {
  required Set<DateTime> photoDates,
  int max = 30,
}) {
  if (!baby.reminder.enabled) return const [];
  final today = DateTime.utc(now.year, now.month, now.day);
  final out = <PlannedReminder>[];
  var from = today;
  final schedule = baby.schedule;
  final finish = schedule.endDate;
  while (out.length < max) {
    if (finish != null && from.isAfter(finish)) break; // finish line passed
    final due = schedule.dueDates(from, from.add(const Duration(days: 120)));
    if (due.isEmpty) {
      from = from.add(const Duration(days: 121));
      continue;
    }
    for (final d in due) {
      if (photoDates.contains(d)) continue;
      final when = DateTime(
        d.year,
        d.month,
        d.day,
        baby.reminder.hour,
        baby.reminder.minute,
      );
      if (!when.isAfter(now)) continue;
      out.add(PlannedReminder(when, d));
      if (out.length >= max) break;
    }
    from = from.add(const Duration(days: 121));
  }
  return out;
}

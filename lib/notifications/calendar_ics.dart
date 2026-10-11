import '../domain/baby.dart';
import '../domain/age_label.dart';

/// Builds an iCalendar (.ics) file with one all-photo reminder per due date for
/// the next [months] months. The web app uses this because browsers on iPhone
/// cannot schedule notifications by themselves; the phone's Calendar can.
///
/// Every event has a stable id, so importing the file again updates the same
/// events instead of adding duplicates.
String buildCalendarIcs(Baby baby, DateTime now, {int months = 36}) {
  final today = DateTime.utc(now.year, now.month, now.day);
  final end = DateTime.utc(now.year, now.month + months, now.day);
  final due = baby.schedule.dueDates(today, end);
  String two(int n) => n.toString().padLeft(2, '0');
  String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}${two(d.month)}${two(d.day)}';
  String esc(String s) => s
      .replaceAll(r'\', r'\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,')
      .replaceAll('\n', r'\n');
  final stamp =
      '${ymd(now.toUtc())}T${two(now.toUtc().hour)}${two(now.toUtc().minute)}00Z';
  final r = baby.reminder;
  final b = StringBuffer()
    ..write('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n')
    ..write('PRODID:-//Baby Photobook//EN\r\nCALSCALE:GREGORIAN\r\n')
    ..write('X-WR-CALNAME:${esc("${baby.name}'s photos")}\r\n');
  for (final d in due) {
    b
      ..write('BEGIN:VEVENT\r\n')
      ..write('UID:${baby.id}-${ymd(d)}@babyphotobook\r\n')
      ..write('DTSTAMP:$stamp\r\n')
      // Floating local time: fires at the chosen hour wherever the phone is.
      ..write('DTSTART:${ymd(d)}T${two(r.hour)}${two(r.minute)}00\r\n')
      ..write('DURATION:PT15M\r\n')
      ..write('SUMMARY:${esc("Time for ${baby.name}'s photo")}\r\n')
      ..write('DESCRIPTION:${esc(ageLabel(baby.birth, d))}\r\n')
      ..write('BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:PT0M\r\n')
      ..write('DESCRIPTION:${esc("Time for ${baby.name}'s photo")}\r\nEND:VALARM\r\n')
      ..write('END:VEVENT\r\n');
  }
  b.write('END:VCALENDAR\r\n');
  return b.toString();
}

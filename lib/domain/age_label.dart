/// Human age labels for timeline cards: "Birth day", "5 days", "3 weeks, 2 days",
/// "4 months", "1 year, 2 months".
String ageLabel(DateTime birth, DateTime date) {
  final b = DateTime.utc(birth.year, birth.month, birth.day);
  final d = DateTime.utc(date.year, date.month, date.day);
  final days = d.difference(b).inDays;
  if (days < 0) return 'Before birth';
  if (days == 0) return 'Birth day';

  var months = (d.year - b.year) * 12 + d.month - b.month;
  if (d.day < b.day) months--;
  if (months < 1) {
    if (days < 14) return _n(days, 'day');
    final w = days ~/ 7, r = days % 7;
    return r == 0 ? _n(w, 'week') : '${_n(w, 'week')}, ${_n(r, 'day')}';
  }
  if (months < 12) return _n(months, 'month');
  final y = months ~/ 12, m = months % 12;
  return m == 0 ? _n(y, 'year') : '${_n(y, 'year')}, ${_n(m, 'month')}';
}

/// Section title used to group the timeline: "Newborn", "Month 3", "Year 2".
String ageSection(DateTime birth, DateTime date) {
  final b = DateTime.utc(birth.year, birth.month, birth.day);
  final d = DateTime.utc(date.year, date.month, date.day);
  var months = (d.year - b.year) * 12 + d.month - b.month;
  if (d.day < b.day) months--;
  if (months < 0) return 'Before birth';
  if (months == 0) return 'First month';
  if (months < 12) return 'Month ${months + 1}';
  return 'Year ${months ~/ 12 + 1}';
}

String _n(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';

/// How old the baby is right now, in words: "born today", "2 days old",
/// "3 weeks, 2 days old"; before the birth: "due in 5 days".
String ageNowLabel(DateTime birth, DateTime now) {
  final b = DateTime.utc(birth.year, birth.month, birth.day);
  final d = DateTime.utc(now.year, now.month, now.day);
  final days = d.difference(b).inDays;
  if (days < 0) return 'due in ${_n(-days, 'day')}';
  if (days == 0) return 'born today';
  return '${ageLabel(birth, now)} old';
}

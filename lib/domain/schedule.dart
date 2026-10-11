/// Photo schedule engine: pure Dart, no Flutter dependencies.
///
/// A schedule is an ordered list of phases chosen by the user. Each phase
/// starts at a baby age and repeats at a frequency until the next phase
/// begins; the last phase continues indefinitely. The finest frequency is
/// one day, so at most one photo is ever due per day.
library;

enum TimeUnit { day, week, month }

/// A span measured from birth, e.g. "2 months".
class Age {
  const Age(this.value, this.unit) : assert(value >= 0);
  final int value;
  final TimeUnit unit;

  static const birth = Age(0, TimeUnit.day);

  /// The calendar date this age is reached for a baby born on [birthDate].
  DateTime from(DateTime birthDate) => _add(_dateOnly(birthDate), unit, value);

  @override
  bool operator ==(Object other) =>
      other is Age && other.value == value && other.unit == unit;

  @override
  int get hashCode => Object.hash(value, unit);
}

/// "Every [every] [unit]s", e.g. every 1 day, every 2 weeks, every 1 month.
class Frequency {
  const Frequency(this.every, this.unit) : assert(every >= 1);
  final int every;
  final TimeUnit unit;

  static const daily = Frequency(1, TimeUnit.day);
  static const weekly = Frequency(1, TimeUnit.week);
  static const monthly = Frequency(1, TimeUnit.month);
}

class Phase {
  const Phase({required this.start, required this.frequency});
  final Age start;
  final Frequency frequency;
}

class PhotoSchedule {
  PhotoSchedule(this.birthDate, List<Phase> phases)
    : assert(phases.isNotEmpty),
      _starts = phases.map((p) => p.start.from(birthDate)).toList(),
      phases = List.unmodifiable(phases) {
    for (var i = 1; i < _starts.length; i++) {
      if (!_starts[i].isAfter(_starts[i - 1])) {
        throw ArgumentError('Phase starts must be strictly increasing');
      }
    }
  }

  final DateTime birthDate;
  final List<Phase> phases;
  final List<DateTime> _starts;

  /// Due dates (date-only, UTC) within [from]..[to] inclusive, ascending.
  List<DateTime> dueDates(DateTime from, DateTime to) {
    final lo = _dateOnly(from), hi = _dateOnly(to);
    final out = <DateTime>[];
    for (var i = 0; i < phases.length; i++) {
      final start = _starts[i];
      final end = i + 1 < phases.length ? _starts[i + 1] : null; // exclusive
      final f = phases[i].frequency;
      if (start.isAfter(hi)) break;
      for (var k = 0; ; k++) {
        // Anchor to the phase start each time so month steps never drift.
        final d = _add(start, f.unit, k * f.every);
        if (d.isAfter(hi) || (end != null && !d.isBefore(end))) break;
        if (!d.isBefore(lo)) out.add(d);
      }
    }
    return out;
  }

  /// First due date strictly after [date], or null never (schedule is endless).
  DateTime nextDueAfter(DateTime date) {
    var window = 400;
    final from = _dateOnly(date).add(const Duration(days: 1));
    while (true) {
      final r = dueDates(from, from.add(Duration(days: window)));
      if (r.isNotEmpty) return r.first;
      window *= 2;
    }
  }
}

DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

DateTime _add(DateTime d, TimeUnit unit, int n) {
  switch (unit) {
    case TimeUnit.day:
      return d.add(Duration(days: n));
    case TimeUnit.week:
      return d.add(Duration(days: 7 * n));
    case TimeUnit.month:
      final total = d.year * 12 + (d.month - 1) + n;
      final y = total ~/ 12, m = total % 12 + 1;
      final lastDay = DateTime.utc(y, m + 1, 0).day;
      return DateTime.utc(y, m, d.day > lastDay ? lastDay : d.day);
  }
}

/// Photo schedule engine: pure Dart, no Flutter dependencies.
///
/// A schedule is an ordered list of phases chosen by the user. Each phase
/// starts at a baby age and repeats at a frequency until the next phase
/// begins; the last phase continues indefinitely. The finest frequency is
/// one day, so at most one photo is ever due per day.
///
/// An optional finish line ([PhotoSchedule.end]) is an age at which the photo
/// series stops: nothing is due after it, and the finish-line day itself always
/// gets a final photo.
library;

enum TimeUnit { day, week, month }

/// Safety limits, so a typo or a runaway tap can never make the schedule (and
/// the reminders built from it) huge. A baby photobook covers childhood: ages
/// go up to 18 years, and the gap between two photos up to a year.
const maxAgeYears = 18;
const maxSteps = 8;

/// Highest age (starts-at age, finish line) in each unit: 18 years.
int maxAgeIn(TimeUnit u) => switch (u) {
  TimeUnit.day => 6574,
  TimeUnit.week => 939,
  TimeUnit.month => maxAgeYears * 12,
};

/// Longest "a photo every N ..." in each unit: one year.
int maxGapIn(TimeUnit u) => switch (u) {
  TimeUnit.day => 365,
  TimeUnit.week => 52,
  TimeUnit.month => 12,
};

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
  PhotoSchedule(this.birthDate, List<Phase> phases, {this.end})
    : assert(phases.isNotEmpty),
      _starts = phases.map((p) => p.start.from(birthDate)).toList(),
      phases = List.unmodifiable(phases) {
    for (var i = 1; i < _starts.length; i++) {
      if (!_starts[i].isAfter(_starts[i - 1])) {
        throw ArgumentError('Phase starts must be strictly increasing');
      }
    }
    if (end != null && !end!.from(birthDate).isAfter(_starts.last)) {
      throw ArgumentError('The finish line must be after the last step starts');
    }
  }

  /// Age at which the series stops, or null if it goes on.
  final Age? end;

  /// The finish-line date, or null if the schedule goes on.
  DateTime? get endDate => end?.from(birthDate);

  final DateTime birthDate;
  final List<Phase> phases;
  final List<DateTime> _starts;

  /// Due dates (date-only, UTC) within [from]..[to] inclusive, ascending.
  List<DateTime> dueDates(DateTime from, DateTime to) {
    final lo = _dateOnly(from);
    var hi = _dateOnly(to);
    final finish = endDate;
    if (finish != null && hi.isAfter(finish)) hi = finish;
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
    // The finish-line day always gets a last photo.
    if (finish != null &&
        !finish.isBefore(lo) &&
        !finish.isAfter(hi) &&
        !out.contains(finish)) {
      out.add(finish);
    }
    return out;
  }

  /// First due date strictly after [date], or null once the finish line has
  /// passed (never null for a schedule without one).
  DateTime? nextDueAfter(DateTime date) {
    var window = 400;
    final from = _dateOnly(date).add(const Duration(days: 1));
    final finish = endDate;
    while (true) {
      if (finish != null && from.isAfter(finish)) return null;
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

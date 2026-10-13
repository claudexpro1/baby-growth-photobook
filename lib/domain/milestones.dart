import 'schedule.dart';

/// A day worth a little celebration: "100 days", "1 year".
class Milestone {
  const Milestone(this.label, this.date);
  final String label;

  /// Date-only (UTC).
  final DateTime date;
}

/// The milestones of a baby born on [birth] that have been reached by [today].
List<Milestone> reachedMilestones(DateTime birth, DateTime today) {
  final b = DateTime.utc(birth.year, birth.month, birth.day);
  final t = DateTime.utc(today.year, today.month, today.day);
  final all = <Milestone>[
    Milestone('1 week', Age(1, TimeUnit.week).from(b)),
    Milestone('1 month', Age(1, TimeUnit.month).from(b)),
    Milestone('100 days', b.add(const Duration(days: 100))),
    Milestone('3 months', Age(3, TimeUnit.month).from(b)),
    Milestone('6 months', Age(6, TimeUnit.month).from(b)),
    Milestone('9 months', Age(9, TimeUnit.month).from(b)),
    for (var y = 1; y <= 18; y++)
      Milestone(
        y == 1 ? '1 year' : '$y years',
        Age(y * 12, TimeUnit.month).from(b),
      ),
  ];
  return all.where((m) => !m.date.isAfter(t)).toList()
    ..sort((a, c) => a.date.compareTo(c.date));
}

import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

void main() {
  final birth = d(2026, 10, 10);

  PhotoSchedule example() => PhotoSchedule(birth, const [
        Phase(start: Age.birth, frequency: Frequency.daily),
        Phase(start: Age(1, TimeUnit.month), frequency: Frequency.weekly),
        Phase(start: Age(6, TimeUnit.month), frequency: Frequency.monthly),
      ]);

  test('daily phase gives one photo per day and ends where next begins', () {
    final dates = example().dueDates(d(2026, 10, 10), d(2026, 11, 20));
    final daily = dates.where((x) => x.isBefore(d(2026, 11, 10))).toList();
    expect(daily.length, 31);
    expect(dates.toSet().length, dates.length); // never two on one day
  });

  test('weekly phase anchors on its start date', () {
    final dates = example().dueDates(d(2026, 11, 10), d(2026, 12, 8));
    expect(dates, [
      d(2026, 11, 10),
      d(2026, 11, 17),
      d(2026, 11, 24),
      d(2026, 12, 1),
      d(2026, 12, 8),
    ]);
  });

  test('last phase continues indefinitely', () {
    final dates = example().dueDates(d(2028, 1, 1), d(2028, 6, 30));
    expect(dates.length, 6);
    expect(dates.first, d(2028, 1, 10));
  });

  test('monthly steps clamp to month end without drifting', () {
    final s = PhotoSchedule(d(2026, 1, 31), const [
      Phase(start: Age.birth, frequency: Frequency.monthly),
    ]);
    expect(s.dueDates(d(2026, 1, 1), d(2026, 4, 30)),
        [d(2026, 1, 31), d(2026, 2, 28), d(2026, 3, 31), d(2026, 4, 30)]);
  });

  test('every N units', () {
    final s = PhotoSchedule(birth, const [
      Phase(start: Age.birth, frequency: Frequency(3, TimeUnit.day)),
    ]);
    expect(s.dueDates(birth, d(2026, 10, 19)),
        [d(2026, 10, 10), d(2026, 10, 13), d(2026, 10, 16), d(2026, 10, 19)]);
  });

  test('nextDueAfter skips ahead across phases', () {
    expect(example().nextDueAfter(d(2026, 11, 9)), d(2026, 11, 10));
    expect(example().nextDueAfter(d(2026, 11, 10)), d(2026, 11, 17));
    expect(example().nextDueAfter(d(2030, 1, 1)), d(2030, 1, 10));
  });

  test('phase starts must be strictly increasing', () {
    expect(
        () => PhotoSchedule(birth, const [
              Phase(start: Age(1, TimeUnit.month), frequency: Frequency.daily),
              Phase(start: Age(30, TimeUnit.day), frequency: Frequency.weekly),
            ]),
        throwsArgumentError);
  });
}

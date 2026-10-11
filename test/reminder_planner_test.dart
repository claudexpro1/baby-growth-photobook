import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/notifications/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

Baby baby({bool enabled = true}) => Baby(
  id: '1',
  name: 'Luna',
  gender: Gender.girl,
  birth: DateTime(2026, 10, 10, 9),
  phases: const [Phase(start: Age.birth, frequency: Frequency.daily)],
  reminder: ReminderSettings(enabled: enabled, hour: 18, minute: 0),
);

void main() {
  test('nothing planned when reminders are off', () {
    expect(
      planReminders(
        baby(enabled: false),
        DateTime(2026, 10, 10, 8),
        photoDates: {},
      ),
      isEmpty,
    );
  });

  test('today is included only if the reminder time has not passed', () {
    final early = planReminders(
      baby(),
      DateTime(2026, 10, 12, 8),
      photoDates: {},
      max: 3,
    );
    expect(early.first.when, DateTime(2026, 10, 12, 18));
    final late = planReminders(
      baby(),
      DateTime(2026, 10, 12, 19),
      photoDates: {},
      max: 3,
    );
    expect(late.first.when, DateTime(2026, 10, 13, 18));
  });

  test('days that already have a photo are skipped', () {
    final plan = planReminders(
      baby(),
      DateTime(2026, 10, 12, 8),
      photoDates: {DateTime.utc(2026, 10, 12)},
      max: 2,
    );
    expect(plan.map((r) => r.when.day), [13, 14]);
  });

  test('respects the maximum window and works far from birth', () {
    final plan = planReminders(
      baby(),
      DateTime(2030, 1, 1),
      photoDates: {},
      max: 30,
    );
    expect(plan.length, 30);
  });
}

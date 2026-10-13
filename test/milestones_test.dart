import 'package:baby_growth_photobook/domain/milestones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('milestones reached by a given day', () {
    final birth = DateTime(2026, 1, 31, 9);
    final m = reachedMilestones(birth, DateTime(2026, 6, 1));
    expect(m.map((x) => x.label), [
      '1 week',
      '1 month',
      '3 months', // Apr 30 comes before day 100 (May 11)
      '100 days',
    ]);
    expect(m[1].date, DateTime.utc(2026, 2, 28)); // month ends clamp
    expect(m[3].date, DateTime.utc(2026, 5, 11));
  });

  test('none before the first week; a first birthday counts', () {
    expect(
      reachedMilestones(DateTime(2026, 10, 10), DateTime(2026, 10, 12)),
      isEmpty,
    );
    final y = reachedMilestones(DateTime(2025, 10, 10), DateTime(2026, 10, 10));
    expect(y.last.label, '1 year');
  });
}

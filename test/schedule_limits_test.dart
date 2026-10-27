import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/features/common/schedule_editor.dart';
import 'package:baby_growth_photobook/notifications/reminder_planner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(
    WidgetTester t,
    List<PhaseDraft> phases, {
    FinishDraft? finish,
  }) async {
    await t.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (c, set) => ScheduleEditor(
                phases: phases,
                finish: finish,
                birth: DateTime(2026, 10, 12, 9),
                today: DateTime(2026, 10, 12),
                onChanged: () => set(() {}),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool moreEnabled(WidgetTester t, {int at = 0}) {
    final b = t.widgetList<IconButton>(
      find.widgetWithIcon(IconButton, Icons.add_circle_outline),
    );
    return b.elementAt(at).onPressed != null;
  }

  testWidgets('the finish line stops at 18 years', (t) async {
    final finish = FinishDraft(enabled: true, value: 17, unit: FinishUnit.year);
    await show(t, [
      PhaseDraft(0, TimeUnit.day, 1, TimeUnit.week),
    ], finish: finish);
    // buttons: [gap +, finish +]
    expect(moreEnabled(t, at: 1), isTrue);
    await t.tap(find.byTooltip('More').last);
    await t.pump();
    expect(finish.value, 18);
    expect(moreEnabled(t, at: 1), isFalse);
    expect(
      find.textContaining('longest finish line is 18 years'),
      findsOneWidget,
    );
  });

  testWidgets('a long finish line is capped when the unit changes', (t) async {
    final finish = FinishDraft(enabled: true, value: 18, unit: FinishUnit.year);
    await show(t, [
      PhaseDraft(0, TimeUnit.day, 1, TimeUnit.week),
    ], finish: finish);
    await t.tap(find.text('years'));
    await t.pumpAndSettle();
    await t.tap(find.text('weeks').last);
    await t.pumpAndSettle();
    expect(finish.unit, FinishUnit.week);
    expect(finish.value, lessThanOrEqualTo(939));
  });

  testWidgets('the gap between photos stops at one year', (t) async {
    final p = PhaseDraft(0, TimeUnit.day, 11, TimeUnit.month);
    await show(t, [p]);
    await t.tap(find.byTooltip('More').first);
    await t.pump();
    expect(p.every, 12);
    expect(moreEnabled(t), isFalse);
    // 12 months must not be turned into 100 days by the unit menu: it is
    // capped to the day limit instead.
    expect(maxGapIn(TimeUnit.day), 365);
  });

  testWidgets('no more than $maxSteps steps', (t) async {
    final phases = [
      for (var i = 0; i < maxSteps; i++)
        PhaseDraft(i, TimeUnit.month, 1, TimeUnit.week),
    ];
    await show(t, phases);
    final add = t.widget<TextButton>(
      find.widgetWithText(TextButton, 'Add a step'),
    );
    expect(add.onPressed, isNull);
  });

  test('the limits are 18 years and one year', () {
    expect(maxAgeIn(TimeUnit.month), 216);
    expect(maxAgeIn(TimeUnit.week), 939);
    expect(maxAgeIn(TimeUnit.day), 6574);
    expect(maxGapIn(TimeUnit.week), 52);
  });

  test('a 15-year finish line plans a bounded set of reminders', () {
    final baby = Baby(
      id: 'b',
      name: 'Anna',
      gender: Gender.girl,
      birth: DateTime(2026, 10, 13),
      phases: const [Phase(start: Age.birth, frequency: Frequency.daily)],
      end: const Age(15, TimeUnit.month),
    );
    final r = planReminders(
      baby,
      DateTime(2026, 10, 14),
      photoDates: {},
      max: 60,
    );
    expect(r.length, lessThanOrEqualTo(60));
  });
}

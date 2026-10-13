import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/features/common/photo_day_picker.dart';
import 'package:baby_growth_photobook/features/common/schedule_editor.dart';
import 'package:baby_growth_photobook/notifications/reminder_planner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('day picker marks days with a photo and returns the tapped day', (
    tester,
  ) async {
    DateTime? result;
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showPhotoDayPicker(
                c,
                first: DateTime(2026, 10, 1),
                last: DateTime(2026, 10, 28),
                initial: DateTime(2026, 10, 15),
                photoDays: {DateTime.utc(2026, 10, 10)},
                dueDays: {
                  DateTime.utc(2026, 10, 10),
                  DateTime.utc(2026, 10, 17),
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Has a photo'), findsOneWidget);
    expect(find.text('Photo day, no photo yet'), findsOneWidget);
    // the day with a photo says so for screen readers
    expect(
      find.bySemanticsLabel(RegExp(r'October 10, 2026.*has a photo')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'October 17, 2026.*photo day')),
      findsOneWidget,
    );
    // days after "last" cannot be chosen
    await tester.tap(
      find.byKey(const Key('day-2026-10-29')),
      warnIfMissed: false,
    );
    await tester.tap(find.byKey(const Key('day-2026-10-20')));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 10, 20));
  });

  testWidgets('finish line switch shows the age choices and the summary', (
    tester,
  ) async {
    final finish = FinishDraft();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScheduleEditor(
              phases: [PhaseDraft(0, TimeUnit.day, 1, TimeUnit.week)],
              finish: finish,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Finish line'), findsOneWidget);
    expect(find.text('2 years'), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(finish.enabled, isTrue);
    await tester.tap(find.text('5 years'));
    await tester.pump();
    expect(finish.toAge(), const Age(60, TimeUnit.month));
    expect(find.textContaining('Finish line at 5 years'), findsOneWidget);
  });

  test('validation: the finish line has to be after the last step', () {
    final birth = DateTime(2026, 10, 10);
    final phases = [
      PhaseDraft(0, TimeUnit.day, 1, TimeUnit.week),
      PhaseDraft(6, TimeUnit.month, 1, TimeUnit.month),
    ];
    final bad = FinishDraft(enabled: true, value: 3, unit: TimeUnit.month);
    expect(validatePhases(birth, phases, finish: bad), contains('finish line'));
    final ok = FinishDraft(enabled: true, value: 24, unit: TimeUnit.month);
    expect(validatePhases(birth, phases, finish: ok), isNull);
    expect(ageSpanLabel(24, TimeUnit.month), '2 years');
    expect(ageSpanLabel(18, TimeUnit.month), '18 months');
  });

  test('reminders stop at the finish line instead of looping forever', () {
    final baby = Baby(
      id: 'b',
      name: 'Luna',
      gender: Gender.girl,
      birth: DateTime(2026, 10, 10),
      phases: const [Phase(start: Age.birth, frequency: Frequency.weekly)],
      end: const Age(1, TimeUnit.month),
    );
    final plan = planReminders(
      baby,
      DateTime(2026, 10, 9),
      photoDates: {},
      max: 60,
    );
    expect(plan.last.photoDate, DateTime.utc(2026, 11, 10)); // the finish day
    expect(plan.length, 6);
    expect(
      planReminders(baby, DateTime(2027, 5, 1), photoDates: {}, max: 60),
      isEmpty,
    );
    // saved and restored with the profile
    final back = Baby.fromJson(baby.toJson());
    expect(back.end, const Age(1, TimeUnit.month));
    expect(Baby.fromJson(baby.copyWith(clearEnd: true).toJson()).end, isNull);
  });
}

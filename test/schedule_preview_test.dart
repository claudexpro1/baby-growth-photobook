import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/features/common/schedule_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    List<PhaseDraft> phases, {
    FinishDraft? finish,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    await tester.pumpWidget(
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

  testWidgets('real dates: first photo days and per-step lines', (
    tester,
  ) async {
    await show(tester, [
      PhaseDraft(0, TimeUnit.day, 1, TimeUnit.day),
      PhaseDraft(2, TimeUnit.day, 1, TimeUnit.week),
    ]);
    expect(find.text('Your first photo days'), findsOneWidget);
    for (final d in ['Mon, Oct 12', 'Tue, Oct 13', 'Wed, Oct 21']) {
      expect(find.widgetWithText(Chip, d), findsOneWidget);
    }
    // Oct 14 is the start of the weekly step, so it is a chip too.
    expect(find.widgetWithText(Chip, 'Wed, Oct 14'), findsOneWidget);
    expect(
      find.textContaining('From Mon, Oct 12 · every day · until Tue, Oct 13'),
      findsOneWidget,
    );
    expect(
      find.textContaining('From Wed, Oct 14 · every week · and so on'),
      findsOneWidget,
    );
    // the 0-based age is spelled out
    expect(find.textContaining('age 2 days is Wed, Oct 14'), findsOneWidget);
  });

  testWidgets('finish line sentence names the final photo day', (tester) async {
    final finish = FinishDraft(enabled: true, value: 5, unit: FinishUnit.week);
    await show(tester, [
      PhaseDraft(0, TimeUnit.day, 2, TimeUnit.week),
    ], finish: finish);
    // born Oct 12 + 5 weeks = Nov 16; fortnightly photos fall on Oct 12, 26,
    // Nov 9, so Nov 16 is an extra final photo.
    expect(
      find.textContaining('Finish line: Mon, Nov 16, 2026'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Last regular photo Mon, Nov 9, then one final photo',
      ),
      findsOneWidget,
    );
  });

  testWidgets('changing a number updates the preview', (tester) async {
    final phases = [PhaseDraft(0, TimeUnit.day, 1, TimeUnit.week)];
    await show(tester, phases);
    expect(find.widgetWithText(Chip, 'Mon, Oct 19'), findsOneWidget);
    await tester.tap(find.byTooltip('More').last); // every 2 weeks
    await tester.pump();
    expect(find.widgetWithText(Chip, 'Mon, Oct 19'), findsNothing);
    expect(find.widgetWithText(Chip, 'Mon, Oct 26'), findsOneWidget);
  });

  testWidgets('a step that starts too early is explained, not a crash', (
    tester,
  ) async {
    await show(tester, [
      PhaseDraft(0, TimeUnit.day, 1, TimeUnit.day),
      PhaseDraft(0, TimeUnit.day, 1, TimeUnit.week),
    ]);
    expect(find.textContaining('each step has to start later'), findsOneWidget);
  });
}

import 'package:baby_growth_photobook/features/common/drive_consent.dart';
import 'package:baby_growth_photobook/features/onboarding/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'birth date range reaches a due date ~10 months ahead and 25 years back',
    () {
      final now = DateTime(2026, 10, 13);
      expect(birthDateLast(now), DateTime(2027, 8, 13));
      expect(birthDateFirst(now), DateTime(2001, 1, 1));
      expect(
        birthDateLast(now).isAfter(now.add(const Duration(days: 280))),
        isTrue,
      );
    },
  );

  testWidgets('drive consent: Continue returns true, Not now returns false', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showDriveConsent(c),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('cannot see the rest of your Drive'),
      findsOneWidget,
    );
    expect(find.textContaining('share link'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}

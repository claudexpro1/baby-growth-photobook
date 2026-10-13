import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/domain/age_label.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/features/baby/baby_page.dart';
import 'package:baby_growth_photobook/features/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show MemoryRepository;

final _noPhoto = find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == 'No photo yet for Anna',
);

void main() {
  test('ageNowLabel: before, on and after the birth', () {
    final birth = DateTime(2026, 10, 12, 14, 5);
    expect(ageNowLabel(birth, DateTime(2026, 10, 7)), 'due in 5 days');
    expect(ageNowLabel(birth, DateTime(2026, 10, 12, 20)), 'born today');
    expect(ageNowLabel(birth, DateTime(2026, 10, 14)), '2 days old');
    expect(ageNowLabel(birth, DateTime(2026, 11, 2)), '3 weeks old');
  });

  final birth = DateTime.now().subtract(const Duration(days: 2));
  final baby = Baby(
    id: 'a',
    name: 'Anna',
    gender: Gender.girl,
    birth: DateTime(birth.year, birth.month, birth.day, 14, 5),
    birthPlace: 'Athens',
    phases: const [Phase(start: Age.birth, frequency: Frequency.daily)],
  );

  Future<void> open(WidgetTester tester, Widget home) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    final repo = MemoryRepository()..data = [baby];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWith((_) async => MemoryStore()),
          babyRepositoryProvider.overrideWith((_) async => repo),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('baby page shows a birth line and the empty-photo avatar', (
    tester,
  ) async {
    await open(tester, const BabyPage(babyId: 'a'));
    expect(find.text('2 days old'), findsOneWidget);
    expect(find.textContaining('born '), findsOneWidget);
    expect(find.textContaining('in Athens'), findsOneWidget);
    expect(_noPhoto, findsOneWidget);
  });

  testWidgets('list card shows "born ... · 2 days old"', (tester) async {
    await open(tester, const HomePage());
    expect(find.textContaining('· 2 days old'), findsOneWidget);
    expect(_noPhoto, findsOneWidget);
  });
}

import 'package:baby_growth_photobook/data/baby_repository.dart';
import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keeps profiles in memory so this UI test does not depend on real file IO
/// (file storage has its own tests).
class MemoryRepository extends BabyRepository {
  MemoryRepository() : super(MemoryStore());
  List<Baby> data = [];
  @override
  Future<List<Baby>> load() async => data;
  @override
  Future<void> save(List<Baby> babies) async => data = babies;
}

void main() {
  testWidgets('first run: add a baby (photos in app only) and see it on home', (
    tester,
  ) async {
    final store = MemoryStore();
    await tester.binding.setSurfaceSize(const Size(400, 900));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWith((_) async => store),
          babyRepositoryProvider.overrideWith((_) async => MemoryRepository()),
        ],
        child: const PhotobookApp(),
      ),
    );
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start with your baby'), findsOneWidget);

    await tester.tap(find.text('Start with your baby'));
    await tester.pumpAndSettle();

    // Step 1: name is required
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text("Please enter your baby's name."), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Luna');
    await tester.tap(find.text('Girl'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 2: storage - must choose; app-only asks for confirmation
    expect(find.text('Where should photos live?'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(
      find.text('Please choose where to keep the photos.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Only in this app'));
    await tester.pumpAndSettle();
    expect(find.text('Keep photos only in the app?'), findsOneWidget);
    await tester.tap(find.text('Keep in the app only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 3: schedule with a preset, step 4: reminders
    expect(find.text('How often?'), findsOneWidget);
    await tester.tap(find.text('Daily, then weekly, then monthly'));
    await tester.pumpAndSettle();
    expect(find.textContaining('From birth: every day'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Reminders'), findsOneWidget);
    await tester.tap(find.byType(Switch)); // turn reminders off
    await tester.pump();

    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Only on this phone'), findsOneWidget);
  });
}

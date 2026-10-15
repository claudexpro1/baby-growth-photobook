import 'package:baby_growth_photobook/data/baby_repository.dart';
import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'photo_sync_test.dart' show FakeCloud;

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
  testWidgets(
    'first run: add a baby (Google Drive required) and see it on home',
    (tester) async {
      final store = MemoryStore();
      await tester.binding.setSurfaceSize(const Size(400, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStoreProvider.overrideWith((_) async => store),
            babyRepositoryProvider.overrideWith(
              (_) async => MemoryRepository(),
            ),
            cloudProvider.overrideWithValue(FakeCloud()),
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

      // Step 2: Google Drive is required; there is no way around it
      expect(
        find.widgetWithText(FilledButton, 'Connect Google Drive'),
        findsOneWidget,
      );
      expect(find.textContaining('needs a Google account'), findsOneWidget);
      expect(find.text('Only in this app'), findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(
        find.textContaining('Please connect Google Drive to continue'),
        findsOneWidget,
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Connect Google Drive'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Google Drive is connected'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 3: schedule with a preset, step 4: reminders
      expect(find.text('How often?'), findsOneWidget);
      await tester.tap(find.text('Daily, then weekly, then monthly'));
      await tester.pumpAndSettle();
      expect(find.textContaining('every day'), findsOneWidget);
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
      // lands on the new baby's page: the next steps are right there
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Luna'), findsWidgets);
      expect(find.text('Saved in Google Drive'), findsOneWidget);
      // and the baby is on the home list when going back
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Not saved to Drive yet'), findsNothing);
    },
  );
}

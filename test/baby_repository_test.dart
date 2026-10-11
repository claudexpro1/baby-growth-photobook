import 'dart:io';

import 'package:baby_growth_photobook/data/baby_repository.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('babies'));
  tearDown(() => dir.deleteSync(recursive: true));

  Baby sample(String id, String name) => Baby(
    id: id,
    name: name,
    gender: Gender.girl,
    birth: DateTime(2026, 10, 10, 14, 30),
    birthPlace: 'Tallinn',
    phases: const [
      Phase(start: Age.birth, frequency: Frequency.daily),
      Phase(
        start: Age(1, TimeUnit.month),
        frequency: Frequency(2, TimeUnit.week),
      ),
    ],
    reminder: const ReminderSettings(enabled: false, hour: 9, minute: 15),
    storage: StorageMode.googleDrive,
  );

  test('empty when nothing saved', () async {
    expect(await BabyRepository(dir).load(), isEmpty);
  });

  test('round-trips several babies', () async {
    final repo = BabyRepository(dir);
    await repo.save([sample('1', 'Luna'), sample('2', 'Mika')]);
    final back = await BabyRepository(dir).load();
    expect(back.map((b) => b.name), ['Luna', 'Mika']);
    final b = back.first;
    expect(b.birth, DateTime(2026, 10, 10, 14, 30));
    expect(b.birthPlace, 'Tallinn');
    expect(b.gender, Gender.girl);
    expect(b.storage, StorageMode.googleDrive);
    expect(b.reminder.enabled, isFalse);
    expect(b.reminder.hour, 9);
    expect(b.phases[1].frequency.every, 2);
    expect(b.phases[1].start, const Age(1, TimeUnit.month));
  });
}

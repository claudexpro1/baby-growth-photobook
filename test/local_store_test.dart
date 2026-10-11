import 'dart:io';
import 'dart:typed_data';

import 'package:baby_growth_photobook/data/local_store_io.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/notifications/calendar_ics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FileStore reads, writes, lists and deletes by prefix', () async {
    final dir = Directory.systemTemp.createTempSync('fs');
    addTearDown(() => dir.deleteSync(recursive: true));
    final s = FileStore(dir);
    expect(await s.read('a/x.jpg'), isNull);
    await s.write('photos/b/1.jpg', Uint8List.fromList([1, 2]));
    await s.write('photos/b/2.jpg', Uint8List.fromList([3]));
    await s.write('photos/c/1.jpg', Uint8List.fromList([4]));
    expect(await s.read('photos/b/1.jpg'), [1, 2]);
    expect((await s.list('photos/b/')).toSet(), {
      'photos/b/1.jpg',
      'photos/b/2.jpg',
    });
    await s.deletePrefix('photos/b/');
    expect(await s.list('photos/b/'), isEmpty);
    expect(await s.read('photos/c/1.jpg'), [4]);
  });

  test('calendar file has stable ids and one event per due day', () {
    final baby = Baby(
      id: 'abc',
      name: 'Luna',
      gender: Gender.girl,
      birth: DateTime(2026, 10, 10),
      phases: const [Phase(start: Age.birth, frequency: Frequency.weekly)],
      reminder: const ReminderSettings(hour: 9, minute: 5),
    );
    final now = DateTime(2026, 10, 11, 12);
    final a = buildCalendarIcs(baby, now, months: 1);
    expect(a, startsWith('BEGIN:VCALENDAR'));
    expect(a, contains('UID:abc-20261017@babyphotobook'));
    expect(a, contains('DTSTART:20261017T090500'));
    expect(a, contains("SUMMARY:Time for Luna's photo"));
    // 17, 24, 31 Oct and 7 Nov fall inside one month from the 11th.
    expect('BEGIN:VEVENT'.allMatches(a).length, 4);
    expect(
      buildCalendarIcs(baby, now, months: 1).contains('UID:abc-20261017'),
      isTrue,
    );
  });
}

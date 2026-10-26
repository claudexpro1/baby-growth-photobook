import 'dart:typed_data';

import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/photo_library.dart';
import 'package:baby_growth_photobook/data/photo_sync.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

import 'photo_sync_test.dart' show FakeCloud;

/// Files that are in the Drive folder but are not the app's: they must change
/// nothing (the real Drive hides files the app did not create anyway).
void main() {
  late PhotoLibrary lib;
  final baby = Baby(
    id: 'b',
    name: 'Luna',
    gender: Gender.girl,
    birth: DateTime(2026, 10, 10),
    phases: const [Phase(start: Age.birth, frequency: Frequency.daily)],
  );
  Uint8List bytes(int v) => Uint8List.fromList([v, v, v]);

  setUp(() => lib = PhotoLibrary(MemoryStore(), 'photos/b'));

  test('restore ignores files that do not follow the naming', () async {
    final cloud = FakeCloud();
    cloud.files['00001_2026-10-10.jpg'] = bytes(1);
    cloud.files['holiday.jpg'] = bytes(2);
    cloud.files['IMG_2231.HEIC'] = bytes(3);
    cloud.files['1_2026-10-10.jpg'] = bytes(4); // wrong padding
    cloud.files['00002_2026-13-45.jpg'] = bytes(5); // not a date
    cloud.files['notes.txt'] = bytes(6);
    final b = (await PhotoSync(cloud).upload(baby, lib)).baby;
    final r = await PhotoSync(cloud).restore(b, lib);
    expect(r.downloaded, 1);
    expect(r.failed, 0);
    expect((await lib.list()).map((p) => p.name.fileName), [
      '00001_2026-10-10.jpg',
    ]);
  });

  test('extra files do not disturb uploads or the numbering', () async {
    final cloud = FakeCloud();
    cloud.files['holiday.jpg'] = bytes(9);
    await lib.add(bytes(1), DateTime(2026, 10, 10));
    final r = await PhotoSync(cloud).upload(baby, lib);
    expect(r.uploaded, 1);
    expect(cloud.files['holiday.jpg'], bytes(9)); // left alone
    await lib.add(bytes(2), DateTime(2026, 10, 17));
    expect((await lib.list()).map((p) => p.name.fileName), [
      '00001_2026-10-10.jpg',
      '00002_2026-10-17.jpg',
    ]);
  });

  test('restoring twice does not create duplicates', () async {
    final cloud = FakeCloud();
    cloud.files['00001_2026-10-10.jpg'] = bytes(1);
    final b = (await PhotoSync(cloud).upload(baby, lib)).baby;
    await PhotoSync(cloud).restore(b, lib);
    final again = await PhotoSync(cloud).restore(b, lib);
    expect(again.downloaded, 0);
    expect((await lib.list()).length, 1);
  });
}

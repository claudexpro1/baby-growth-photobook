import 'dart:io';

import 'package:baby_growth_photobook/data/photo_library.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/naming.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/export/photobook_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('photobook PDF is produced for a Greek name', () async {
    final dir = Directory.systemTemp.createTempSync('pdf');
    addTearDown(() => dir.deleteSync(recursive: true));
    final photos = <PhotoEntry>[];
    for (var i = 1; i <= 7; i++) {
      final name = PhotoName(i, DateTime.utc(2026, 10, i));
      final f = File('${dir.path}/${name.fileName}')
        ..writeAsBytesSync(img.encodeJpg(img.Image(width: 80, height: 60)));
      photos.add(PhotoEntry(name, f, synced: true));
    }
    final baby = Baby(
      id: 'g',
      name: 'Μαρία',
      gender: Gender.girl,
      birth: DateTime(2026, 10, 1),
      birthPlace: 'Αθήνα',
      phases: const [Phase(start: Age.birth, frequency: Frequency.daily)],
    );
    final bytes = await buildPhotobookPdf(baby, photos);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(5000));
  });
}

import 'package:baby_growth_photobook/domain/age_label.dart';
import 'package:baby_growth_photobook/domain/naming.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('file names', () {
    test('zero padded to 5 digits', () {
      expect(
        photoFileName(1, DateTime.utc(2026, 10, 10)),
        '00001_2026-10-10.jpg',
      );
      expect(
        photoFileName(12345, DateTime.utc(2027, 1, 5)),
        '12345_2027-01-05.jpg',
      );
    });
    test('parse round trip and rejects other files', () {
      final n = PhotoName.parse('00042_2026-12-31.jpg')!;
      expect(n.number, 42);
      expect(n.date, DateTime.utc(2026, 12, 31));
      expect(n.fileName, '00042_2026-12-31.jpg');
      expect(PhotoName.parse('IMG_0001.jpg'), isNull);
      expect(PhotoName.parse('.synced.json'), isNull);
    });
  });

  group('age labels', () {
    final birth = DateTime(2026, 10, 10, 14, 30);
    String at(int y, int m, int d) => ageLabel(birth, DateTime(y, m, d));
    test('first days and weeks', () {
      expect(at(2026, 10, 10), 'Birth day');
      expect(at(2026, 10, 11), '1 day');
      expect(at(2026, 10, 15), '5 days');
      expect(at(2026, 10, 24), '2 weeks');
      expect(at(2026, 10, 31), '3 weeks');
      expect(at(2026, 10, 26), '2 weeks, 2 days');
    });
    test('months and years', () {
      expect(at(2026, 11, 10), '1 month');
      expect(at(2027, 4, 9), '5 months');
      expect(at(2027, 10, 10), '1 year');
      expect(at(2028, 1, 12), '1 year, 3 months');
    });
    test('sections', () {
      expect(ageSection(birth, DateTime(2026, 10, 20)), 'First month');
      expect(ageSection(birth, DateTime(2026, 11, 12)), 'Month 2');
      expect(ageSection(birth, DateTime(2027, 10, 10)), 'Year 2');
    });
  });
}

/// Photo file names: `NNNNN_YYYY-MM-DD.jpg`, e.g. `00001_2026-10-10.jpg`.
/// Five digits leave room for ~270 years of daily photos.
class PhotoName {
  const PhotoName(this.number, this.date);
  final int number;

  /// Date-only (UTC).
  final DateTime date;

  String get fileName => photoFileName(number, date);

  static final _re = RegExp(
    r'^(\d{5,})_(\d{4})-(\d{2})-(\d{2})\.jpe?g$',
    caseSensitive: false,
  );

  static PhotoName? parse(String name) {
    final m = _re.firstMatch(name);
    if (m == null) return null;
    final y = int.parse(m[2]!), mo = int.parse(m[3]!), d = int.parse(m[4]!);
    final date = DateTime.utc(y, mo, d);
    // 2026-13-45 would roll over into another day: not one of our names.
    if (date.year != y || date.month != mo || date.day != d) return null;
    return PhotoName(int.parse(m[1]!), date);
  }
}

String photoFileName(int number, DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${number.toString().padLeft(5, '0')}_'
      '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}.jpg';
}

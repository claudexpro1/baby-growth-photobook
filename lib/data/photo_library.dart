import 'dart:convert';
import 'dart:typed_data';

import '../domain/naming.dart';
import 'local_store.dart';

class PhotoEntry {
  const PhotoEntry(
    this.name,
    this._store,
    this._key, {
    required this.synced,
    this.rev = 0,
  });
  final PhotoName name;
  final LocalStore _store;
  final String _key;

  /// True once the photo is safely in the user's cloud folder.
  final bool synced;

  /// Changes when the picture is replaced (retake), so views know to reload.
  final int rev;

  int get number => name.number;
  DateTime get date => name.date;

  Future<Uint8List> bytes() async =>
      await _store.read(_key) ?? (throw StateError('Photo file is missing'));

  @override
  bool operator ==(Object other) =>
      other is PhotoEntry &&
      other._key == _key &&
      other.synced == synced &&
      other.rev == rev;

  @override
  int get hashCode => Object.hash(_key, synced, rev);
}

/// The photos of one baby, kept under [prefix] (e.g. `photos/<babyId>`) on the
/// device. When cloud storage is connected this is a cache and each photo also
/// exists in the user's folder; the file names alone are enough to rebuild the
/// timeline.
class PhotoLibrary {
  PhotoLibrary(this.store, String prefix) : prefix = '$prefix/';

  final LocalStore store;
  final String prefix;
  final Map<String, int> _revs = {};

  String get _syncedKey => '$prefix.synced.json';
  String _key(PhotoName n) => '$prefix${n.fileName}';

  Future<Set<String>> _syncedNames() async {
    final raw = await store.read(_syncedKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(utf8.decode(raw)) as List).cast<String>().toSet();
    } on FormatException {
      return {};
    }
  }

  Future<void> _writeSynced(Set<String> names) => store.write(
    _syncedKey,
    Uint8List.fromList(utf8.encode(jsonEncode(names.toList()))),
  );

  /// All photos, oldest first.
  Future<List<PhotoEntry>> list() async {
    final synced = await _syncedNames();
    final out = <PhotoEntry>[];
    for (final key in await store.list(prefix)) {
      final n = PhotoName.parse(key.substring(prefix.length));
      if (n != null) {
        out.add(
          PhotoEntry(
            n,
            store,
            key,
            synced: synced.contains(n.fileName),
            rev: _revs[key] ?? 0,
          ),
        );
      }
    }
    out.sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.number.compareTo(b.number);
    });
    return out;
  }

  /// Saves a photo for [date]. At most one photo per day: a second photo for
  /// the same day replaces the first and keeps its number.
  Future<PhotoEntry> add(Uint8List bytes, DateTime date) async {
    final day = DateTime.utc(date.year, date.month, date.day);
    final existing = await list();
    final same = existing.where((p) => p.date == day).toList();
    final number = same.isNotEmpty
        ? same.first.number
        : (existing.isEmpty
              ? 1
              : existing.map((p) => p.number).reduce((a, b) => a > b ? a : b) +
                    1);
    final name = PhotoName(number, day);
    final key = _key(name);
    await store.write(key, bytes);
    _revs[key] = (_revs[key] ?? 0) + 1;
    final synced = await _syncedNames();
    if (synced.remove(name.fileName)) await _writeSynced(synced);
    return PhotoEntry(name, store, key, synced: false, rev: _revs[key]!);
  }

  Future<void> markSynced(PhotoName name) async {
    final s = await _syncedNames();
    if (s.add(name.fileName)) await _writeSynced(s);
  }

  Future<void> delete(PhotoEntry p) async {
    await store.delete(_key(p.name));
    final s = await _syncedNames();
    if (s.remove(p.name.fileName)) await _writeSynced(s);
  }

  /// Removes every photo of this baby from this device.
  Future<void> deleteAll() => store.deletePrefix(prefix);

  /// Adds a photo that came from the cloud (already synced).
  Future<void> addFromCloud(PhotoName name, Uint8List bytes) async {
    await store.write(_key(name), bytes);
    await markSynced(name);
  }
}

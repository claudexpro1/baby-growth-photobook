import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/naming.dart';

class PhotoEntry {
  const PhotoEntry(this.name, this.file, {required this.synced});
  final PhotoName name;
  final File file;

  /// True once the photo is safely in the user's cloud folder.
  final bool synced;

  int get number => name.number;
  DateTime get date => name.date;
}

/// The photos of one baby, kept in [dir] on the phone. When cloud storage is
/// connected this folder is a cache and each photo also exists in the user's
/// folder; the file names alone are enough to rebuild the timeline.
class PhotoLibrary {
  PhotoLibrary(this.dir) : _syncedFile = File('${dir.path}/.synced.json');

  final Directory dir;
  final File _syncedFile;

  Future<Set<String>> _syncedNames() async {
    if (!await _syncedFile.exists()) return {};
    try {
      return (jsonDecode(await _syncedFile.readAsString()) as List)
          .cast<String>()
          .toSet();
    } on FormatException {
      return {};
    }
  }

  Future<void> _writeSynced(Set<String> names) async {
    await dir.create(recursive: true);
    await _syncedFile.writeAsString(jsonEncode(names.toList()));
  }

  /// All photos, oldest first.
  Future<List<PhotoEntry>> list() async {
    if (!await dir.exists()) return [];
    final synced = await _syncedNames();
    final out = <PhotoEntry>[];
    await for (final e in dir.list()) {
      if (e is! File) continue;
      final n = PhotoName.parse(e.uri.pathSegments.last);
      if (n != null) {
        out.add(PhotoEntry(n, e, synced: synced.contains(n.fileName)));
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
    await dir.create(recursive: true);
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
    final file = File('${dir.path}/${name.fileName}');
    await file.writeAsBytes(bytes, flush: true);
    final synced = await _syncedNames();
    if (synced.remove(name.fileName)) await _writeSynced(synced);
    return PhotoEntry(name, file, synced: false);
  }

  Future<void> markSynced(PhotoName name) async {
    final s = await _syncedNames();
    if (s.add(name.fileName)) await _writeSynced(s);
  }

  Future<void> delete(PhotoEntry p) async {
    if (await p.file.exists()) await p.file.delete();
    final s = await _syncedNames();
    if (s.remove(p.name.fileName)) await _writeSynced(s);
  }

  /// Adds a photo that came from the cloud (already synced).
  Future<void> addFromCloud(PhotoName name, Uint8List bytes) async {
    await dir.create(recursive: true);
    await File('${dir.path}/${name.fileName}').writeAsBytes(bytes, flush: true);
    await markSynced(name);
  }
}

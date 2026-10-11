import 'dart:typed_data';

/// Where profiles and the on-device photo cache are kept. On phones this is
/// the app's private folder; in the browser it is IndexedDB. Keys look like
/// `photos/<babyId>/00001_2026-10-10.jpg`.
abstract class LocalStore {
  Future<Uint8List?> read(String key);
  Future<void> write(String key, Uint8List bytes);
  Future<void> delete(String key);

  /// Keys that start with [prefix].
  Future<List<String>> list(String prefix);

  Future<void> deletePrefix(String prefix) async {
    for (final k in await list(prefix)) {
      await delete(k);
    }
  }
}

/// Keeps everything in memory. Used by tests.
class MemoryStore extends LocalStore {
  final Map<String, Uint8List> data = {};

  @override
  Future<Uint8List?> read(String key) async => data[key];

  @override
  Future<void> write(String key, Uint8List bytes) async => data[key] = bytes;

  @override
  Future<void> delete(String key) async => data.remove(key);

  @override
  Future<List<String>> list(String prefix) async =>
      data.keys.where((k) => k.startsWith(prefix)).toList();
}

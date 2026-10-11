import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'local_store.dart';

/// Phone storage: plain files inside the app's private support folder.
class FileStore extends LocalStore {
  FileStore(this.root);
  final Directory root;

  File _file(String key) => File('${root.path}/$key');

  @override
  Future<Uint8List?> read(String key) async {
    final f = _file(key);
    return await f.exists() ? await f.readAsBytes() : null;
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    final f = _file(key);
    await f.parent.create(recursive: true);
    // Temp file first so a crash can't leave a half-written file.
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> delete(String key) async {
    final f = _file(key);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<List<String>> list(String prefix) async {
    final slash = prefix.lastIndexOf('/');
    final dirKey = slash < 0 ? '' : prefix.substring(0, slash);
    final dir = Directory('${root.path}/$dirKey');
    if (!await dir.exists()) return [];
    final out = <String>[];
    await for (final e in dir.list(recursive: true)) {
      if (e is! File || e.path.endsWith('.tmp')) continue;
      final key = e.path.substring(root.path.length + 1);
      if (key.startsWith(prefix)) out.add(key);
    }
    return out;
  }
}

Future<LocalStore> openLocalStore() async =>
    FileStore(await getApplicationSupportDirectory());

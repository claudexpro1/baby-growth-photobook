import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

import 'local_store.dart';

/// Browser storage: IndexedDB, one record per file.
class IdbStore extends LocalStore {
  IdbStore(this._db);
  final Database _db;
  static const _store = 'files';

  @override
  Future<Uint8List?> read(String key) async {
    final txn = _db.transaction(_store, idbModeReadOnly);
    final v = await txn.objectStore(_store).getObject(key);
    await txn.completed;
    if (v == null) return null;
    return v is Uint8List ? v : Uint8List.fromList((v as List).cast<int>());
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    final txn = _db.transaction(_store, idbModeReadWrite);
    await txn.objectStore(_store).put(bytes, key);
    await txn.completed;
  }

  @override
  Future<void> delete(String key) async {
    final txn = _db.transaction(_store, idbModeReadWrite);
    await txn.objectStore(_store).delete(key);
    await txn.completed;
  }

  @override
  Future<List<String>> list(String prefix) async {
    final txn = _db.transaction(_store, idbModeReadOnly);
    final keys = await txn.objectStore(_store).getAllKeys();
    await txn.completed;
    return keys.cast<String>().where((k) => k.startsWith(prefix)).toList();
  }
}

Future<LocalStore> openLocalStore() async {
  final db = await idbFactoryBrowser.open(
    'baby_photobook',
    version: 1,
    onUpgradeNeeded: (e) => e.database.createObjectStore('files'),
  );
  return IdbStore(db);
}

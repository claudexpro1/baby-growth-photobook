import 'dart:io' show SocketException;
import 'dart:typed_data';

import 'package:baby_growth_photobook/data/cloud_storage.dart';
import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/photo_library.dart';
import 'package:baby_growth_photobook/data/photo_sync.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCloud implements CloudStorage {
  final files = <String, Uint8List>{}; // name -> bytes (single folder)
  bool offline = false;
  bool failUploads = false;
  void Function()? onUpload; // runs while an upload is in flight
  int created = 0;

  void _check() {
    if (offline) throw const SocketException('offline');
  }

  @override
  String get providerName => 'Fake';
  @override
  Future<bool> isSignedIn() async => true;
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<String> ensureBabyFolder(String babyName, {String? existingId}) async {
    _check();
    if (existingId != null) return existingId;
    created++;
    return 'folder-1';
  }

  @override
  Future<String> ensureSharedFolder(
    String babyFolderId, {
    String? existingId,
  }) async => 'shared-1';
  @override
  Future<List<RemoteFile>> listBabyFolders() async =>
      files.isEmpty ? [] : [const RemoteFile('folder-1', 'Luna')];
  @override
  Future<void> upload(String folderId, String name, Uint8List bytes) async {
    _check();
    final isPhoto = name.endsWith('.jpg');
    if (isPhoto) onUpload?.call();
    if (isPhoto && failUploads) throw const SocketException('upload failed');
    files[name] = bytes;
  }

  @override
  Future<List<RemoteFile>> list(String folderId) async {
    _check();
    return [for (final n in files.keys) RemoteFile(n, n)];
  }

  @override
  Future<Uint8List> download(String fileId) async => files[fileId]!;
  @override
  Future<void> deleteByName(String folderId, String name) async =>
      files.remove(name);
  @override
  Future<String> shareFolderLink(String folderId) async =>
      'https://example/$folderId';
  @override
  Future<void> unshareFolder(String folderId) async {}
  @override
  Uri folderUrl(String folderId) => Uri.parse('https://example/$folderId');
}

void main() {
  late MemoryStore store;
  late PhotoLibrary lib;
  final baby = Baby(
    id: 'b',
    name: 'Luna',
    gender: Gender.girl,
    birth: DateTime(2026, 10, 10),
    phases: const [Phase(start: Age.birth, frequency: Frequency.daily)],
    storage: StorageMode.googleDrive,
  );
  Uint8List bytes(int v) => Uint8List.fromList([v, v, v]);

  setUp(() {
    store = MemoryStore();
    lib = PhotoLibrary(store, 'photos/b');
  });

  test('numbers photos in order and keeps one photo per day', () async {
    await lib.add(bytes(1), DateTime(2026, 10, 10, 8));
    await lib.add(bytes(2), DateTime(2026, 10, 17, 9));
    await lib.add(
      bytes(3),
      DateTime(2026, 10, 10, 20),
    ); // same day: replaces #1
    final all = await lib.list();
    expect(all.map((p) => p.name.fileName), [
      '00001_2026-10-10.jpg',
      '00002_2026-10-17.jpg',
    ]);
    expect(await all.first.bytes(), bytes(3));
  });

  test('upload sends unsynced photos once', () async {
    final cloud = FakeCloud();
    await lib.add(bytes(1), DateTime(2026, 10, 10));
    final r = await PhotoSync(cloud).upload(baby, lib);
    expect(r.uploaded, 1);
    expect(r.baby.driveFolderId, 'folder-1');
    expect(cloud.files.keys.toSet(), {'00001_2026-10-10.jpg', 'profile.json'});
    final again = await PhotoSync(cloud).upload(r.baby, lib);
    expect(again.uploaded, 0);
    expect((await lib.list()).single.synced, isTrue);
  });

  test('a retake is re-uploaded under the same name', () async {
    final cloud = FakeCloud();
    await lib.add(bytes(1), DateTime(2026, 10, 10));
    var b = (await PhotoSync(cloud).upload(baby, lib)).baby;
    await lib.add(bytes(9), DateTime(2026, 10, 10));
    expect((await lib.list()).single.synced, isFalse);
    b = (await PhotoSync(cloud).upload(b, lib)).baby;
    expect(cloud.files['00001_2026-10-10.jpg'], bytes(9));
    expect(cloud.files.length, 2); // photo + profile.json
  });

  test('a failed upload keeps the photo queued, never loses it', () async {
    final cloud = FakeCloud();
    final b = (await PhotoSync(cloud).upload(baby, lib)).baby; // folder created
    await lib.add(bytes(1), DateTime(2026, 10, 10));
    cloud.failUploads = true;
    final r = await PhotoSync(cloud).upload(b, lib);
    expect(r.failed, 1);
    expect((await lib.list()).single.synced, isFalse);
    cloud.failUploads = false;
    expect((await PhotoSync(cloud).upload(b, lib)).uploaded, 1);
  });

  test('fully offline: sync throws and the photo stays on the phone', () async {
    final cloud = FakeCloud()..offline = true;
    await lib.add(bytes(1), DateTime(2026, 10, 10));
    await expectLater(
      PhotoSync(cloud).upload(baby, lib),
      throwsA(isA<SocketException>()),
    );
    expect((await lib.list()).single.synced, isFalse);
  });

  test('restore rebuilds the phone cache from the cloud folder', () async {
    final cloud = FakeCloud()
      ..files['00001_2026-10-10.jpg'] = bytes(1)
      ..files['00002_2026-10-17.jpg'] = bytes(2)
      ..files['notes.txt'] = bytes(0);
    final r = await PhotoSync(cloud).restore(baby, lib);
    expect(r.downloaded, 2);
    final all = await lib.list();
    expect(all.length, 2);
    expect(all.every((p) => p.synced), isTrue);
    // next new photo continues the numbering
    final next = await lib.add(bytes(3), DateTime(2026, 10, 24));
    expect(next.number, 3);
  });

  test('a retake during upload is not marked as synced', () async {
    final cloud = FakeCloud();
    await lib.add(bytes(1), DateTime(2026, 10, 10));
    cloud.onUpload = () {
      // the parent retakes the photo while the old one is uploading
      store.data['photos/b/00001_2026-10-10.jpg'] = Uint8List.fromList([
        9,
        9,
        9,
        9,
      ]);
    };
    final r = await PhotoSync(cloud).upload(baby, lib);
    expect(r.uploaded, 0);
    expect((await lib.list()).single.synced, isFalse);
    cloud.onUpload = null;
    await PhotoSync(cloud).upload(r.baby, lib);
    expect(cloud.files['00001_2026-10-10.jpg'], [9, 9, 9, 9]);
  });

  test('timeline is ordered by date even for backfilled photos', () async {
    await lib.add(bytes(1), DateTime(2026, 10, 20));
    final late = await lib.add(bytes(2), DateTime(2026, 10, 12)); // gets #2
    expect(late.number, 2);
    expect((await lib.list()).map((p) => p.date.day), [12, 20]);
  });

  test(
    'profile is saved with the photos and restored on a new phone',
    () async {
      final cloud = FakeCloud();
      await lib.add(bytes(1), DateTime(2026, 10, 10));
      await PhotoSync(cloud).upload(baby, lib);
      expect(cloud.files.containsKey('profile.json'), isTrue);

      // a new phone: nothing local, same cloud
      final found = await PhotoSync(cloud).findProfiles();
      expect(found, hasLength(1));
      expect(found.single.id, 'b');
      expect(found.single.name, 'Luna');
      expect(found.single.driveFolderId, 'folder-1');
      expect(found.single.storage, StorageMode.googleDrive);
      expect(found.single.phases, hasLength(1));

      final fresh = PhotoLibrary(MemoryStore(), 'photos/b');
      final r = await PhotoSync(cloud).restore(found.single, fresh);
      expect(r.downloaded, 1);
      expect((await fresh.list()).single.number, 1);
    },
  );

  test('a folder without a readable profile is skipped', () async {
    final cloud = FakeCloud();
    cloud.files['00001_2026-10-10.jpg'] = bytes(1);
    cloud.files['profile.json'] = Uint8List.fromList([1, 2, 3]);
    expect(await PhotoSync(cloud).findProfiles(), isEmpty);
  });
}

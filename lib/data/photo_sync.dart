import 'dart:convert';
import 'dart:typed_data';

import '../domain/baby.dart';
import '../domain/naming.dart';
import 'cloud_storage.dart';
import 'photo_library.dart';

class SyncResult {
  const SyncResult(
    this.baby, {
    this.uploaded = 0,
    this.downloaded = 0,
    this.failed = 0,
  });

  /// The baby, with cloud folder ids filled in if they were just created.
  final Baby baby;
  final int uploaded;
  final int downloaded;
  final int failed;
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

const profileFileName = 'profile.json';

Uint8List _profileBytes(Baby baby) =>
    Uint8List.fromList(utf8.encode(jsonEncode(baby.toJson())));

/// Moves photos between the phone cache and the user's cloud folder.
class PhotoSync {
  PhotoSync(this.cloud);
  final CloudStorage cloud;

  /// Uploads every photo that is not yet in the cloud. Safe to call often;
  /// failures (for example no connection) leave the photo queued for next time.
  Future<SyncResult> upload(Baby baby, PhotoLibrary library) async {
    final folderId = await cloud.ensureBabyFolder(
      baby.name,
      existingId: baby.driveFolderId,
    );
    final updated = baby.driveFolderId == folderId
        ? baby
        : baby.copyWith(driveFolderId: folderId);
    var ok = 0, failed = 0;
    // The profile travels with the photos, so a new phone can restore everything.
    try {
      await cloud.upload(folderId, profileFileName, _profileBytes(updated));
    } catch (_) {
      // Not fatal: the next sync saves it again.
    }
    for (final p in (await library.list()).where((p) => !p.synced)) {
      try {
        // A retake during the upload replaces the file; only mark it as synced
        // if it is exactly what we uploaded, otherwise it stays queued.
        final bytes = await p.bytes();
        // Cloud implementations replace a file with the same name (retakes).
        await cloud.upload(folderId, p.name.fileName, bytes);
        final after = await p.bytes();
        if (_same(bytes, after)) {
          await library.markSynced(p.name);
          ok++;
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
    }
    return SyncResult(updated, uploaded: ok, failed: failed);
  }

  /// Rebuilds the phone cache from the cloud folder (new phone, reinstall).
  Future<SyncResult> restore(Baby baby, PhotoLibrary library) async {
    final folderId = await cloud.ensureBabyFolder(
      baby.name,
      existingId: baby.driveFolderId,
    );
    final have = (await library.list()).map((p) => p.name.fileName).toSet();
    var n = 0, failed = 0;
    for (final f in await cloud.list(folderId)) {
      final name = PhotoName.parse(f.name);
      if (name == null || have.contains(name.fileName)) continue;
      try {
        await library.addFromCloud(name, await cloud.download(f.id));
        n++;
      } catch (_) {
        failed++;
      }
    }
    final updated = baby.driveFolderId == folderId
        ? baby
        : baby.copyWith(driveFolderId: folderId);
    return SyncResult(updated, downloaded: n, failed: failed);
  }

  /// Babies saved in the user's cloud folders (new phone, reinstall). Folders
  /// without a readable `profile.json` are skipped.
  Future<List<Baby>> findProfiles() async {
    final out = <Baby>[];
    for (final folder in await cloud.listBabyFolders()) {
      try {
        final file = (await cloud.list(folder.id))
            .where((f) => f.name == profileFileName)
            .firstOrNull;
        if (file == null) continue;
        final json = jsonDecode(
          utf8.decode(await cloud.download(file.id)),
        ) as Map<String, dynamic>;
        out.add(
          Baby.fromJson(json).copyWith(
            storage: StorageMode.googleDrive,
            driveFolderId: folder.id,
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  /// Removes a photo from the cloud folder too.
  Future<void> delete(Baby baby, PhotoName name) async {
    final id = baby.driveFolderId;
    if (id == null) return;
    await cloud.deleteByName(id, name.fileName);
  }
}

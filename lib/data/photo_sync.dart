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
    for (final p in (await library.list()).where((p) => !p.synced)) {
      try {
        // A retake during the upload rewrites the same file; only mark it as
        // synced if it is exactly what we read, otherwise it stays queued.
        final before = await p.file.stat();
        final bytes = await p.file.readAsBytes();
        // Cloud implementations replace a file with the same name (retakes).
        await cloud.upload(folderId, p.name.fileName, bytes);
        final after = await p.file.stat();
        if (before.modified == after.modified && before.size == after.size) {
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

  /// Removes a photo from the cloud folder too.
  Future<void> delete(Baby baby, PhotoName name) async {
    final id = baby.driveFolderId;
    if (id == null) return;
    await cloud.deleteByName(id, name.fileName);
  }
}

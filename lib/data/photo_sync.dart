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
    this.found = 0,
    this.ignored = 0,
    this.folderName,
  });

  /// The baby, with cloud folder ids filled in if they were just created.
  final Baby baby;
  final int uploaded;
  final int downloaded;
  final int failed;

  /// Photos Drive has in the baby's folder (also those already on the phone),
  /// and files there that are not named like the app's photos.
  final int found;
  final int ignored;
  final String? folderName;
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Old location: inside the baby's photo folder. Read for migration only.
const legacyProfileFileName = 'profile.json';

/// New location: `BabyPhotobook/_App data/profile_<babyId>.json`.
String profileFileName(Baby baby) => 'profile_${baby.id}.json';

/// The Drive folder name for a baby: the name, plus the birth date when
/// another baby has the same name, so two babies never share one folder.
String driveFolderNameFor(Baby baby, Iterable<Baby> all) {
  final clash = all.any(
    (o) =>
        o.id != baby.id &&
        o.name.trim().toLowerCase() == baby.name.trim().toLowerCase(),
  );
  if (!clash) return baby.name;
  final b = baby.birth;
  final d =
      '${b.year}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}';
  return '${baby.name} ($d)';
}

Uint8List _profileBytes(Baby baby) =>
    Uint8List.fromList(utf8.encode(jsonEncode(baby.toJson())));

/// Moves photos between the phone cache and the user's cloud folder.
class PhotoSync {
  PhotoSync(this.cloud);
  final CloudStorage cloud;

  /// Finds or creates the baby's folder and keeps its name in step with the
  /// baby's name (a renamed baby renames the folder; the id stays).
  Future<Baby> _folder(Baby baby, Iterable<Baby> allBabies) async {
    final want = driveFolderNameFor(baby, allBabies);
    final folderId = await cloud.ensureBabyFolder(
      want,
      existingId: baby.driveFolderId,
    );
    var name = baby.driveFolderName;
    if (folderId == baby.driveFolderId && name != want) {
      try {
        await cloud.renameFolder(folderId, want);
        name = want;
      } catch (_) {
        // Not fatal: the next sync tries again.
      }
    } else if (folderId != baby.driveFolderId) {
      name = want; // just found or made under this name
    }
    return baby.driveFolderId == folderId && baby.driveFolderName == name
        ? baby
        : baby.copyWith(driveFolderId: folderId, driveFolderName: name);
  }

  /// Uploads every photo that is not yet in the cloud. Safe to call often;
  /// failures (for example no connection) leave the photo queued for next time.
  Future<SyncResult> upload(
    Baby baby,
    PhotoLibrary library, {
    Iterable<Baby> allBabies = const [],
  }) async {
    final updated = await _folder(baby, allBabies);
    final folderId = updated.driveFolderId!;
    var ok = 0, failed = 0;
    // The profile is saved in the app-data folder (not among the photos), so a
    // new phone can restore everything.
    try {
      final dataId = await cloud.ensureAppDataFolder();
      await cloud.upload(
        dataId,
        profileFileName(updated),
        _profileBytes(updated),
      );
      // Migrate: only after the new copy is safe, bin the old one.
      await cloud.deleteByName(folderId, legacyProfileFileName);
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

  /// Uploads what is waiting, then downloads what Drive has and this phone
  /// does not (the other direction of "Sync now").
  Future<SyncResult> sync(
    Baby baby,
    PhotoLibrary library, {
    Iterable<Baby> allBabies = const [],
  }) async {
    final up = await upload(baby, library, allBabies: allBabies);
    final down = await restore(up.baby, library, allBabies: allBabies);
    return SyncResult(
      down.baby,
      uploaded: up.uploaded,
      downloaded: down.downloaded,
      failed: up.failed + down.failed,
      found: down.found,
      ignored: down.ignored,
      folderName: down.folderName,
    );
  }

  /// Rebuilds the phone cache from the cloud folder (new phone, reinstall).
  /// Another folder with exactly the same name (a duplicate left by an earlier
  /// setup) is read too, so photos are not stranded in it.
  Future<SyncResult> restore(
    Baby baby,
    PhotoLibrary library, {
    Iterable<Baby> allBabies = const [],
  }) async {
    final updated = await _folder(baby, allBabies);
    final folderId = updated.driveFolderId!;
    final have = (await library.list()).map((p) => p.name.fileName).toSet();
    final folders = [folderId];
    try {
      for (final f in await cloud.listBabyFolders()) {
        if (f.id != folderId && f.name == updated.driveFolderName) {
          folders.add(f.id);
        }
      }
    } catch (_) {
      // Only the baby's own folder then.
    }
    var n = 0, failed = 0, found = 0, ignored = 0;
    for (final id in folders) {
      for (final f in await cloud.list(id)) {
        final name = PhotoName.parse(f.name);
        if (name == null) {
          ignored++;
          continue;
        }
        if (have.contains(name.fileName)) {
          found++;
          continue;
        }
        try {
          await library.addFromCloud(name, await cloud.download(f.id));
          have.add(name.fileName);
          found++;
          n++;
        } catch (_) {
          failed++;
        }
      }
    }
    return SyncResult(
      updated,
      downloaded: n,
      failed: failed,
      found: found,
      ignored: ignored,
      folderName: updated.driveFolderName,
    );
  }

  /// Babies saved in the user's cloud (new phone, reinstall): the profiles in
  /// the app-data folder, plus old-style `profile.json` files left inside baby
  /// folders. Unreadable profiles are skipped.
  Future<List<Baby>> findProfiles() async {
    final out = <Baby>[];
    final seen = <String>{};
    Baby? parse(Uint8List bytes, {String? folderId}) {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final b = Baby.fromJson(json);
      return b.copyWith(driveFolderId: folderId ?? b.driveFolderId);
    }

    try {
      for (final f in await cloud.listAppData()) {
        if (!f.name.startsWith('profile_') || !f.name.endsWith('.json')) {
          continue;
        }
        try {
          final b = parse(await cloud.download(f.id));
          if (b != null && seen.add(b.id)) out.add(b);
        } catch (_) {
          continue;
        }
      }
    } catch (_) {
      // fall through to the old layout
    }
    for (final folder in await cloud.listBabyFolders()) {
      try {
        final file = (await cloud.list(folder.id))
            .where((f) => f.name == legacyProfileFileName)
            .firstOrNull;
        if (file == null) continue;
        final b = parse(await cloud.download(file.id), folderId: folder.id);
        if (b != null && seen.add(b.id)) out.add(b);
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

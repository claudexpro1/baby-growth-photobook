import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/baby.dart';
import '../notifications/reminder_service.dart';
import 'baby_repository.dart';
import 'cloud_storage.dart';
import 'drive_cloud.dart';
import 'photo_library.dart';
import 'photo_sync.dart';

/// Overridable in tests.
final cloudProvider = Provider<CloudStorage>((_) => DriveCloud.instance);

final appDirProvider = FutureProvider<Directory>(
  (_) => getApplicationSupportDirectory(),
);

final babyRepositoryProvider = FutureProvider<BabyRepository>((ref) async {
  return BabyRepository(await ref.watch(appDirProvider.future));
});

final photoLibraryProvider = FutureProvider.family<PhotoLibrary, String>((
  ref,
  babyId,
) async {
  final dir = await ref.watch(appDirProvider.future);
  return PhotoLibrary(Directory('${dir.path}/photos/$babyId'));
});

class BabiesNotifier extends AsyncNotifier<List<Baby>> {
  @override
  Future<List<Baby>> build() async =>
      (await ref.watch(babyRepositoryProvider.future)).load();

  Future<void> _save(List<Baby> next) async {
    await (await ref.read(babyRepositoryProvider.future)).save(next);
    state = AsyncData(next);
  }

  Future<void> add(Baby baby) async {
    await _save([...?state.value, baby]);
    unawaited(reschedule());
  }

  Future<void> updateBaby(Baby baby) async {
    await _save([
      for (final b in state.value ?? <Baby>[]) b.id == baby.id ? baby : b,
    ]);
    unawaited(reschedule());
  }

  /// Removes the profile and the photos cached on this phone. Photos already in
  /// the user's cloud folder are left untouched.
  Future<void> remove(Baby baby) async {
    final lib = await ref.read(photoLibraryProvider(baby.id).future);
    if (await lib.dir.exists()) await lib.dir.delete(recursive: true);
    await _save([
      for (final b in state.value ?? <Baby>[])
        if (b.id != baby.id) b,
    ]);
    unawaited(reschedule());
  }

  /// Re-plans reminders for all babies. Safe to call at any time.
  Future<void> reschedule() async {
    try {
      final babies = state.value ?? [];
      final dates = <String, Set<DateTime>>{};
      for (final b in babies) {
        final lib = await ref.read(photoLibraryProvider(b.id).future);
        dates[b.id] = (await lib.list()).map((p) => p.date).toSet();
      }
      await ReminderService.instance.rescheduleAll(
        babies,
        (b) async => dates[b.id] ?? {},
      );
    } catch (_) {
      // Notifications unavailable (e.g. permission denied); the app still works.
    }
  }
}

final babiesProvider = AsyncNotifierProvider<BabiesNotifier, List<Baby>>(
  BabiesNotifier.new,
);

/// Outcome of a sync attempt, in words a parent can read.
class SyncOutcome {
  const SyncOutcome(this.message, {this.ok = true});
  final String message;
  final bool ok;
}

class PhotosNotifier extends AsyncNotifier<List<PhotoEntry>> {
  PhotosNotifier(this.babyId);
  final String babyId;

  Baby? get _baby => (ref.read(babiesProvider).value ?? [])
      .where((b) => b.id == babyId)
      .firstOrNull;

  Future<PhotoLibrary> get _lib =>
      ref.read(photoLibraryProvider(babyId).future);

  @override
  Future<List<PhotoEntry>> build() async =>
      (await ref.watch(photoLibraryProvider(babyId).future)).list();

  Future<void> _refresh() async => state = AsyncData(await (await _lib).list());

  /// Saves a photo for [date] and starts uploading it if Drive is connected.
  Future<void> addPhoto(Uint8List bytes, DateTime date) async {
    await (await _lib).add(bytes, date);
    await _refresh();
    unawaited(ref.read(babiesProvider.notifier).reschedule());
    unawaited(sync());
  }

  Future<void> delete(PhotoEntry p) async {
    final baby = _baby;
    await (await _lib).delete(p);
    await _refresh();
    if (baby != null && baby.storage == StorageMode.googleDrive) {
      try {
        await PhotoSync(ref.read(cloudProvider)).delete(baby, p.name);
      } catch (_) {
        /* offline: the cloud copy stays until the next cleanup */
      }
    }
    unawaited(ref.read(babiesProvider.notifier).reschedule());
  }

  Future<SyncOutcome> sync({bool restore = false}) async {
    final baby = _baby;
    if (baby == null || baby.storage != StorageMode.googleDrive) {
      return const SyncOutcome('Photos are kept in this app only.');
    }
    final cloud = ref.read(cloudProvider);
    try {
      if (!await cloud.isSignedIn()) {
        return const SyncOutcome('Google Drive is not connected.', ok: false);
      }
      final lib = await _lib;
      final sync = PhotoSync(cloud);
      final r = restore
          ? await sync.restore(baby, lib)
          : await sync.upload(baby, lib);
      if (r.baby.driveFolderId != baby.driveFolderId) {
        await ref.read(babiesProvider.notifier).updateBaby(r.baby);
      }
      await _refresh();
      if (r.failed > 0) {
        return SyncOutcome(
          '${r.failed} photo(s) are waiting to upload. We will try again.',
          ok: false,
        );
      }
      return SyncOutcome(
        restore
            ? 'Restored ${r.downloaded} photo(s) from Google Drive.'
            : 'All photos are safe in Google Drive.',
      );
    } catch (e) {
      return const SyncOutcome(
        'Could not reach Google Drive. Your photos are saved on this phone and will upload later.',
        ok: false,
      );
    }
  }
}

final photosProvider =
    AsyncNotifierProvider.family<PhotosNotifier, List<PhotoEntry>, String>(
      PhotosNotifier.new,
    );

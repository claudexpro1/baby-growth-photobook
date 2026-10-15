import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';

import 'cloud_storage.dart';
import 'google_auth.dart';

/// Google Drive storage. Uses only the `drive.file` scope, so the app can see
/// and touch just the files and folders it created itself, never the rest of
/// the user's Drive.
///
/// Needs a Google Cloud OAuth setup; see "Google Drive setup" in the README.
/// Google needs the user to sign in again, and no tap is in progress to show
/// Google's window. The app shows a "Reconnect" button instead.
class DriveNeedsReconnect implements Exception {
  const DriveNeedsReconnect();
  @override
  String toString() => 'DriveNeedsReconnect';
}

class DriveCloud implements CloudStorage {
  DriveCloud._();
  static final DriveCloud instance = DriveCloud._();

  /// For tests: talks to a fake Drive instead of Google.
  DriveCloud.withApi(Future<drive.DriveApi> Function() api)
    : _apiOverride = api;
  Future<drive.DriveApi> Function()? _apiOverride;

  /// The names say it: people look at these in Drive and must not change them.
  static const rootFolderName =
      'BabyPhotobook (app folder - do not edit or delete)';
  static const appDataFolderName = '_App data (do not delete)';

  /// Names used before the warning was added; found and renamed on first use.
  static const legacyRootFolderName = 'BabyPhotobook';
  static const legacyAppDataFolderName = '_App data';
  static const folderNote =
      'Created by Baby Photobook. Please do not rename, move or delete this '
      'folder or the files in it: the app needs them to show and restore '
      'your photos.';
  static const _scopes = [drive.DriveApi.driveFileScope];
  static const _folderMime = 'application/vnd.google-apps.folder';

  @override
  String get providerName => 'Google Drive';

  Future<void> _init() => GoogleAuth.ensureInit();

  @override
  Future<bool> isSignedIn() async {
    await _init();
    return await GoogleSignIn.instance.authorizationClient
            .authorizationForScopes(_scopes) !=
        null;
  }

  @override
  Future<void> signIn() async {
    await _init();
    await GoogleSignIn.instance.authorizationClient.authorizeScopes(_scopes);
  }

  @override
  Future<void> signOut() async {
    await _init();
    await GoogleSignIn.instance.signOut();
  }

  Future<drive.DriveApi> _api() async {
    if (_apiOverride != null) return _apiOverride!();
    await _init();
    return drive.DriveApi(
      GoogleAuthClient(() async {
        final h = await GoogleSignIn.instance.authorizationClient
            .authorizationHeaders(
              _scopes,
              promptIfNecessary: GoogleAuth.mayPrompt,
            );
        if (h == null) throw const DriveNeedsReconnect();
        return h;
      }),
    );
  }

  String _esc(String s) => s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

  Future<String?> _find(drive.DriveApi api, String name, String parent) async {
    final r = await api.files.list(
      q:
          "name = '${_esc(name)}' and '$parent' in parents and "
          "mimeType = '$_folderMime' and trashed = false",
      $fields: 'files(id)',
      pageSize: 1,
    );
    return r.files?.isNotEmpty == true ? r.files!.first.id : null;
  }

  Future<String> _ensure(drive.DriveApi api, String name, String parent) async {
    final found = await _find(api, name, parent);
    if (found != null) return found;
    final created = await api.files.create(
      drive.File(
        name: name,
        mimeType: _folderMime,
        parents: [parent],
        description: name == rootFolderName || name == appDataFolderName
            ? folderNote
            : null,
      ),
      $fields: 'id',
    );
    return created.id!;
  }

  /// A folder with the warning name, or the same folder under its old name
  /// (renamed in place, so its id, photos and share links stay the same).
  Future<String> _ensureWarned(
    drive.DriveApi api,
    String name,
    String legacy,
    String parent,
  ) async {
    final found = await _find(api, name, parent);
    if (found != null) return found;
    final old = await _find(api, legacy, parent);
    if (old == null) return _ensure(api, name, parent);
    try {
      await api.files.update(
        drive.File(name: name, description: folderNote),
        old,
      );
    } catch (_) {
      /* the old name still works; the rename is tried again next time */
    }
    return old;
  }

  Future<String> _ensureRoot(drive.DriveApi api) =>
      _ensureWarned(api, rootFolderName, legacyRootFolderName, 'root');

  /// Looks for the root folder under either name; never changes anything.
  Future<String?> _findRoot(drive.DriveApi api) async =>
      await _find(api, rootFolderName, 'root') ??
      await _find(api, legacyRootFolderName, 'root');

  Future<String?> _findAppData(drive.DriveApi api, String root) async =>
      await _find(api, appDataFolderName, root) ??
      await _find(api, legacyAppDataFolderName, root);

  /// True if the folder id still exists and is not in the bin.
  Future<bool> _alive(drive.DriveApi api, String id) async {
    try {
      final f = await api.files.get(id, $fields: 'id,trashed') as drive.File;
      return f.trashed != true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> ensureBabyFolder(String babyName, {String? existingId}) async {
    final api = await _api();
    if (existingId != null && await _alive(api, existingId)) return existingId;
    final root = await _ensureRoot(api);
    return _ensure(api, babyName, root);
  }

  @override
  Future<void> renameFolder(String folderId, String newName) async {
    final api = await _api();
    await api.files.update(drive.File(name: newName), folderId);
  }

  @override
  Future<String> ensureAppDataFolder() async {
    final api = await _api();
    final root = await _ensureRoot(api);
    return _ensureWarned(api, appDataFolderName, legacyAppDataFolderName, root);
  }

  @override
  Future<List<RemoteFile>> listAppData() async {
    final api = await _api();
    final root = await _findRoot(api);
    if (root == null) return [];
    final data = await _findAppData(api, root);
    return data == null ? [] : list(data);
  }

  @override
  Future<String> ensureSharedFolder(
    String babyFolderId, {
    String? existingId,
  }) async {
    final api = await _api();
    if (existingId != null && await _alive(api, existingId)) return existingId;
    return _ensure(api, 'Shared', babyFolderId);
  }

  @override
  Future<List<RemoteFile>> listBabyFolders() async {
    final api = await _api();
    final root = await _findRoot(api);
    if (root == null) return [];
    final out = <RemoteFile>[];
    String? token;
    do {
      final r = await api.files.list(
        q: "'$root' in parents and mimeType = '$_folderMime' and trashed = false",
        $fields: 'nextPageToken,files(id,name)',
        pageSize: 100,
        pageToken: token,
      );
      for (final f in r.files ?? <drive.File>[]) {
        if (f.name != 'Shared' &&
            f.name != appDataFolderName &&
            f.name != legacyAppDataFolderName) {
          out.add(RemoteFile(f.id!, f.name!));
        }
      }
      token = r.nextPageToken;
    } while (token != null);
    return out;
  }

  @override
  Future<void> upload(String folderId, String name, Uint8List bytes) async {
    final api = await _api();
    await deleteByName(folderId, name); // replace, never duplicate
    await api.files.create(
      drive.File(name: name, parents: [folderId]),
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
      $fields: 'id',
    );
  }

  @override
  Future<List<RemoteFile>> list(String folderId) async {
    final api = await _api();
    final out = <RemoteFile>[];
    String? token;
    do {
      final r = await api.files.list(
        q: "'$folderId' in parents and mimeType != '$_folderMime' and trashed = false",
        $fields: 'nextPageToken,files(id,name)',
        pageSize: 200,
        pageToken: token,
      );
      for (final f in r.files ?? <drive.File>[]) {
        out.add(RemoteFile(f.id!, f.name!));
      }
      token = r.nextPageToken;
    } while (token != null);
    return out;
  }

  @override
  Future<Uint8List> download(String fileId) async {
    final api = await _api();
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final b = BytesBuilder(copy: false);
    await for (final chunk in media.stream) {
      b.add(chunk);
    }
    return b.takeBytes();
  }

  @override
  Future<void> deleteByName(String folderId, String name) async {
    final api = await _api();
    final r = await api.files.list(
      q: "name = '${_esc(name)}' and '$folderId' in parents and trashed = false",
      $fields: 'files(id)',
    );
    for (final f in r.files ?? <drive.File>[]) {
      // Move to the Drive bin (recoverable for 30 days) rather than erasing.
      await api.files.update(drive.File(trashed: true), f.id!);
    }
  }

  @override
  Future<String> shareFolderLink(String folderId) async {
    final api = await _api();
    await api.permissions.create(
      drive.Permission(type: 'anyone', role: 'reader'),
      folderId,
    );
    return 'https://drive.google.com/drive/folders/$folderId?usp=sharing';
  }

  @override
  Future<void> unshareFolder(String folderId) async {
    final api = await _api();
    final r = await api.permissions.list(
      folderId,
      $fields: 'permissions(id,type)',
    );
    for (final p in r.permissions ?? <drive.Permission>[]) {
      if (p.type == 'anyone') await api.permissions.delete(folderId, p.id!);
    }
  }

  @override
  Uri folderUrl(String folderId) =>
      Uri.parse('https://drive.google.com/drive/folders/$folderId');
}

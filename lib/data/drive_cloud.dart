import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'cloud_storage.dart';

/// Google Drive storage. Uses only the `drive.file` scope, so the app can see
/// and touch just the files and folders it created itself, never the rest of
/// the user's Drive.
///
/// Needs a Google Cloud OAuth setup; see "Google Drive setup" in the README.
class DriveCloud implements CloudStorage {
  DriveCloud._();
  static final DriveCloud instance = DriveCloud._();

  static const rootFolderName = 'BabyPhotobook';
  static const _scopes = [drive.DriveApi.driveFileScope];
  static const _folderMime = 'application/vnd.google-apps.folder';

  // Optional build-time settings: --dart-define=GOOGLE_SERVER_CLIENT_ID=...
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  bool _initialized = false;

  @override
  String get providerName => 'Google Drive';

  Future<void> _init() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
      clientId: kIsWeb
          ? (_webClientId.isEmpty ? null : _webClientId)
          : (_iosClientId.isEmpty ? null : _iosClientId),
    );
    _initialized = true;
  }

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
    await _init();
    return drive.DriveApi(
      _AuthClient(() async {
        final h = await GoogleSignIn.instance.authorizationClient
            .authorizationHeaders(_scopes, promptIfNecessary: true);
        if (h == null) throw StateError('Not signed in to Google Drive');
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
      drive.File(name: name, mimeType: _folderMime, parents: [parent]),
      $fields: 'id',
    );
    return created.id!;
  }

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
    final root = await _ensure(api, rootFolderName, 'root');
    return _ensure(api, babyName, root);
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

class _AuthClient extends http.BaseClient {
  _AuthClient(this._headers);
  final Future<Map<String, String>> Function() _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers.addAll(await _headers());
    return _inner.send(request);
  }
}

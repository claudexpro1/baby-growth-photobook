import 'dart:typed_data';

class RemoteFile {
  const RemoteFile(this.id, this.name);
  final String id;
  final String name;
}

/// A user-owned cloud location for photos. Implemented for Google Drive;
/// the interface keeps sync logic independent of the provider (and testable).
abstract class CloudStorage {
  /// Name shown to the user, e.g. "Google Drive".
  String get providerName;

  /// Whether the user has already granted access (no prompt shown).
  Future<bool> isSignedIn();

  /// Shows the provider's sign-in/consent UI. Throws if the user cancels.
  Future<void> signIn();

  Future<void> signOut();

  /// Finds or creates `BabyPhotobook/<babyName>/` and returns its id.
  Future<String> ensureBabyFolder(String babyName, {String? existingId});

  /// Finds or creates the `Shared` subfolder of a baby folder.
  Future<String> ensureSharedFolder(String babyFolderId, {String? existingId});

  /// The baby folders inside `BabyPhotobook` (empty if there is none yet).
  /// Never creates anything.
  Future<List<RemoteFile>> listBabyFolders();

  Future<void> upload(String folderId, String name, Uint8List bytes);

  Future<List<RemoteFile>> list(String folderId);

  Future<Uint8List> download(String fileId);

  Future<void> deleteByName(String folderId, String name);

  /// Makes the folder viewable by anyone with the link and returns that link.
  Future<String> shareFolderLink(String folderId);

  /// Stops link sharing for the folder.
  Future<void> unshareFolder(String folderId);

  /// Web address that opens the folder in the provider's app/site.
  Uri folderUrl(String folderId);
}

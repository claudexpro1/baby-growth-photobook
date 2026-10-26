import 'local_store.dart';

/// The app stores its data in the browser (IndexedDB). Outside the browser
/// (tests) a store is always provided by the test itself.
Future<LocalStore> openLocalStore() async =>
    throw UnsupportedError('Local storage is only available in the browser');

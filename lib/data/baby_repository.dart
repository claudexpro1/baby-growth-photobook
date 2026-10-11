import 'dart:convert';
import 'dart:typed_data';

import '../domain/baby.dart';
import 'local_store.dart';

/// Stores baby profiles as one JSON document in the [LocalStore]. The photos
/// themselves live in the user's cloud folder; this only holds profiles and
/// settings.
class BabyRepository {
  BabyRepository(this._store);

  final LocalStore _store;
  static const _key = 'babies.json';

  Future<List<Baby>> load() async {
    final bytes = await _store.read(_key);
    if (bytes == null) return [];
    final raw = jsonDecode(utf8.decode(bytes)) as List;
    return raw.map((b) => Baby.fromJson(b as Map<String, dynamic>)).toList();
  }

  Future<void> save(List<Baby> babies) => _store.write(
    _key,
    Uint8List.fromList(
      utf8.encode(jsonEncode(babies.map((b) => b.toJson()).toList())),
    ),
  );
}

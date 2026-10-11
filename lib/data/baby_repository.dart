import 'dart:convert';
import 'dart:io';

import '../domain/baby.dart';

/// Stores baby profiles as one JSON file in [dir]. The photos themselves live
/// in the user's cloud folder; this only holds profiles and settings.
class BabyRepository {
  BabyRepository(Directory dir) : _file = File('${dir.path}/babies.json');

  final File _file;

  Future<List<Baby>> load() async {
    if (!await _file.exists()) return [];
    final raw = jsonDecode(await _file.readAsString()) as List;
    return raw.map((b) => Baby.fromJson(b as Map<String, dynamic>)).toList();
  }

  Future<void> save(List<Baby> babies) async {
    await _file.parent.create(recursive: true);
    // Write to a temp file first so a crash can't leave a half-written profile.
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode(babies.map((b) => b.toJson()).toList()));
    await tmp.rename(_file.path);
  }
}

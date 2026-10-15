import 'dart:convert';

import 'package:baby_growth_photobook/data/drive_cloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A tiny Drive in memory: folders and files with name, parent, description.
class _FakeDrive {
  final items = <String, Map<String, dynamic>>{};
  int _n = 0;

  String add(String name, String parent, {String mime = 'folder'}) {
    final id = 'id${++_n}';
    items[id] = {'id': id, 'name': name, 'parent': parent, 'mime': mime};
    return id;
  }

  Map<String, dynamic>? byName(String name) => items.values
      .where((i) => i['name'] == name)
      .cast<Map<String, dynamic>?>()
      .firstOrNull;

  late final client = MockClient((req) async {
    http.Response json(Object o) => http.Response(
      jsonEncode(o),
      200,
      headers: {'content-type': 'application/json'},
    );
    final path = req.url.path;
    if (req.method == 'GET' && path.endsWith('/files')) {
      final q = req.url.queryParameters['q'] ?? '';
      final name = RegExp(r"name = '((?:[^'\\]|\\.)*)'")
          .firstMatch(q)
          ?.group(1);
      final parent = RegExp(r"'([^']+)' in parents").firstMatch(q)?.group(1);
      final foldersOnly = q.contains(
        "mimeType = 'application/vnd.google-apps.folder'",
      );
      final files = items.values.where((i) {
        if (name != null && i['name'] != name) return false;
        if (parent != null && i['parent'] != parent) return false;
        if (foldersOnly && i['mime'] != 'folder') return false;
        return true;
      });
      return json({
        'files': [
          for (final f in files) {'id': f['id'], 'name': f['name']},
        ],
      });
    }
    if (req.method == 'POST' && path.endsWith('/files')) {
      final b = jsonDecode(req.body) as Map<String, dynamic>;
      final id = add(
        b['name'] as String,
        (b['parents'] as List).first as String,
      );
      items[id]!['description'] = b['description'];
      return json({'id': id});
    }
    if (req.method == 'PATCH') {
      final id = path.split('/').last;
      final b = jsonDecode(req.body) as Map<String, dynamic>;
      items[id]!.addAll({
        if (b['name'] != null) 'name': b['name'],
        if (b['description'] != null) 'description': b['description'],
      });
      return json({'id': id});
    }
    return http.Response('unexpected ${req.method} $path', 500);
  });
}

void main() {
  DriveCloud cloudOver(_FakeDrive d) =>
      DriveCloud.withApi(() async => drive.DriveApi(d.client));

  test(
    'new folders carry the do-not-edit warning in name and description',
    () async {
      final d = _FakeDrive();
      final cloud = cloudOver(d);
      final baby = await cloud.ensureBabyFolder('Anna');
      await cloud.ensureAppDataFolder();
      final root = d.byName(DriveCloud.rootFolderName)!;
      expect(root['description'], DriveCloud.folderNote);
      expect(d.byName(DriveCloud.appDataFolderName)!['description'], isNotNull);
      expect(d.items[baby]!['name'], 'Anna'); // baby folders keep the name
      expect(DriveCloud.rootFolderName, contains('do not edit or delete'));
    },
  );

  test(
    'old-name folders are renamed in place: same ids, no duplicates',
    () async {
      final d = _FakeDrive();
      final root = d.add(DriveCloud.legacyRootFolderName, 'root');
      final data = d.add(DriveCloud.legacyAppDataFolderName, root);
      final anna = d.add('Anna', root);
      final cloud = cloudOver(d);

      expect(await cloud.ensureBabyFolder('Anna'), anna);
      expect(await cloud.ensureAppDataFolder(), data);
      expect(d.items[root]!['name'], DriveCloud.rootFolderName);
      expect(d.items[data]!['name'], DriveCloud.appDataFolderName);
      expect(d.items[root]!['description'], DriveCloud.folderNote);
      expect(d.items.length, 3); // nothing new was created
      // and a second run changes nothing
      await cloud.ensureBabyFolder('Anna');
      expect(d.items.length, 3);
    },
  );

  test(
    'looking for babies finds old-name folders and changes nothing',
    () async {
      final d = _FakeDrive();
      final root = d.add(DriveCloud.legacyRootFolderName, 'root');
      d.add(DriveCloud.legacyAppDataFolderName, root);
      d.add('Shared', root);
      d.add('Anna', root);
      final cloud = cloudOver(d);

      final babies = await cloud.listBabyFolders();
      expect(babies.map((f) => f.name), ['Anna']);
      expect(d.items[root]!['name'], DriveCloud.legacyRootFolderName);
      expect(await cloud.listAppData(), isEmpty);
    },
  );

  test(
    'extra folders and files the user added by hand are not baby folders',
    () async {
      final d = _FakeDrive();
      final root = d.add(DriveCloud.rootFolderName, 'root');
      d.add(DriveCloud.appDataFolderName, root);
      d.add('Anna', root);
      final cloud = cloudOver(d);
      // a file dropped beside the baby folders is not a folder: not listed
      d.add('holiday.jpg', root, mime: 'image/jpeg');
      expect((await cloud.listBabyFolders()).map((f) => f.name), ['Anna']);
    },
  );
}

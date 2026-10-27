import 'package:baby_growth_photobook/data/google_auth.dart';
import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/data/session_keeper.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'photo_sync_test.dart' show FakeCloud;

class _Cloud extends FakeCloud {
  bool signedIn = false;
  bool refuse = false;
  int signIns = 0;
  bool? promptAllowed;
  @override
  Future<bool> isSignedIn() async => signedIn;
  @override
  Future<void> signIn() async {
    signIns++;
    promptAllowed = GoogleAuth.mayPrompt;
    if (refuse) throw Exception('window blocked');
    signedIn = true;
  }
}

Baby _baby({String? folder = 'f1'}) => Baby(
  id: 'b',
  name: 'Luna',
  gender: Gender.girl,
  birth: DateTime(2026, 10, 10),
  phases: const [Phase(start: Age.birth, frequency: Frequency.daily)],
  driveFolderId: folder,
);

Future<void> _tap(WidgetTester t, _Cloud cloud, Baby baby) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: [cloudProvider.overrideWithValue(cloud)],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => renewDriveOnTap(ref, baby),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('go'));
  await t.pump();
}

void main() {
  testWidgets('a lapsed sign-in is renewed inside the tap', (t) async {
    final cloud = _Cloud();
    await _tap(t, cloud, _baby());
    expect(cloud.signIns, 1);
    expect(cloud.promptAllowed, isTrue);
  });

  testWidgets('a live sign-in is left alone', (t) async {
    final cloud = _Cloud()..signedIn = true;
    await _tap(t, cloud, _baby());
    expect(cloud.signIns, 0);
  });

  testWidgets('Drive that was never connected is not touched', (t) async {
    final cloud = _Cloud();
    await _tap(t, cloud, _baby(folder: null));
    expect(cloud.signIns, 0);
  });

  testWidgets('a refused renewal does not throw', (t) async {
    final cloud = _Cloud()..refuse = true;
    await _tap(t, cloud, _baby());
    expect(cloud.signIns, 1);
    expect(t.takeException(), isNull);
  });
}

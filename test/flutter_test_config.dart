import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Tests run in a phone-sized window by default (the test window is 800x600,
/// which the app would treat as a tablet). Tests of the wide layouts set their
/// own size.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(400, 800);
    view.devicePixelRatio = 1;
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset();
  });
  await testMain();
}

import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// The phone or laptop camera, seen through the browser. A fake version is
/// used in tests.
abstract class CameraService {
  /// False where there is no in-app camera (tests on the VM, other platforms).
  bool get supported;

  /// Opens the camera. [front] picks the selfie camera instead of the back one.
  /// Throws when the camera is blocked or missing.
  Future<void> start({bool front = false});

  /// Width divided by height of the live picture, once it is known.
  double? get aspect;

  /// More than one camera to switch between?
  Future<bool> canSwitch();

  /// The live picture.
  Widget buildPreview();

  /// A still JPEG of what the camera sees now.
  Future<Uint8List> capture();

  /// Turns the camera off.
  void dispose();
}

import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'camera_service.dart';

CameraService createCameraService() => _NoCamera();

/// Used where the app has no in-app camera.
class _NoCamera implements CameraService {
  @override
  bool get supported => false;
  @override
  double? get aspect => null;
  @override
  Future<void> start({bool front = false}) =>
      throw UnsupportedError('No in-app camera here');
  @override
  Future<bool> canSwitch() async => false;
  @override
  Widget buildPreview() => const SizedBox();
  @override
  Future<Uint8List> capture() =>
      throw UnsupportedError('No in-app camera here');
  @override
  void dispose() {}
}

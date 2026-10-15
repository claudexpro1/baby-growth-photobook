import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'camera_service.dart';

CameraService createCameraService() => WebCameraService();

/// The browser camera (getUserMedia): a live <video> shown in the page and a
/// canvas to take the still.
class WebCameraService implements CameraService {
  WebCameraService() {
    _holder = web.document.createElement('div') as web.HTMLDivElement;
    _holder.style
      ..width = '100%'
      ..height = '100%'
      ..overflow = 'hidden'
      ..backgroundColor = 'black';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int id) => _holder,
    );
  }

  static int _count = 0;
  final String _viewType = 'baby-photobook-camera-${_count++}';
  late final web.HTMLDivElement _holder;
  web.HTMLVideoElement? _video;
  web.MediaStream? _stream;

  @override
  bool get supported => true;

  @override
  double? get aspect {
    final v = _video;
    if (v == null || v.videoWidth == 0 || v.videoHeight == 0) return null;
    return v.videoWidth / v.videoHeight;
  }

  void _stopTracks() {
    final tracks =
        _stream?.getTracks().toDart ?? const <web.MediaStreamTrack>[];
    for (final t in tracks) {
      t.stop();
    }
    _stream = null;
  }

  @override
  Future<void> start({bool front = false}) async {
    _stopTracks();
    final devices = web.window.navigator.mediaDevices;
    final constraints = web.MediaStreamConstraints(
      video: {
        'facingMode': {'ideal': front ? 'user' : 'environment'},
        'width': {'ideal': 1920},
        'height': {'ideal': 1440},
      }.jsify()!,
      audio: false.toJS,
    );
    final stream = await devices.getUserMedia(constraints).toDart;
    _stream = stream;

    final video = web.document.createElement('video') as web.HTMLVideoElement;
    video
      ..autoplay = true
      ..muted = true
      ..srcObject = stream;
    video.setAttribute('playsinline', 'true');
    video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'cover';
    _holder.replaceChildren(video);
    _video = video;
    final ready = Completer<void>();
    video.onloadedmetadata = ((web.Event _) {
      if (!ready.isCompleted) ready.complete();
    }).toJS;
    await video.play().toDart;
    await ready.future.timeout(const Duration(seconds: 10), onTimeout: () {});
  }

  @override
  Future<bool> canSwitch() async {
    try {
      final list =
          (await web.window.navigator.mediaDevices.enumerateDevices().toDart)
              .toDart;
      return list.where((d) => d.kind == 'videoinput').length > 1;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget buildPreview() => HtmlElementView(viewType: _viewType);

  @override
  Future<Uint8List> capture() async {
    final v = _video;
    if (v == null || v.videoWidth == 0) {
      throw StateError('The camera is not ready yet');
    }
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = v.videoWidth
      ..height = v.videoHeight;
    final ctx = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
    ctx.drawImage(v, 0, 0);
    final done = Completer<web.Blob>();
    canvas.toBlob(
      ((web.Blob? b) {
        if (b == null) {
          done.completeError(StateError('Could not take the picture'));
        } else {
          done.complete(b);
        }
      }).toJS,
      'image/jpeg',
      0.92.toJS,
    );
    final blob = await done.future;
    final buffer = await blob.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  @override
  void dispose() {
    _stopTracks();
    _video?.srcObject = null;
    _holder.textContent = '';
    _video = null;
  }
}

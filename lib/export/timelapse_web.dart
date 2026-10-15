import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'timelapse.dart';

TimelapseExporter createTimelapseExporter() => WebTimelapseExporter();

const _width = 720;
const _height = 960;

/// Draws each photo on a canvas and records the canvas with the browser's own
/// video recorder (MediaRecorder). Nothing leaves the device.
class WebTimelapseExporter implements TimelapseExporter {
  @override
  bool get supported {
    try {
      return _pickMime() != null;
    } catch (_) {
      return false;
    }
  }

  /// MP4 where the browser can (Safari, newer Chrome), otherwise WebM.
  static String? _pickMime() {
    for (final m in const [
      'video/mp4;codecs=avc1',
      'video/mp4',
      'video/webm;codecs=vp9',
      'video/webm;codecs=vp8',
      'video/webm',
    ]) {
      if (web.MediaRecorder.isTypeSupported(m)) return m;
    }
    return null;
  }

  @override
  Future<TimelapseResult> make(
    List<TimelapseFrame> frames, {
    required int frameMs,
    bool showLabel = true,
    void Function(int done, int total)? onProgress,
  }) async {
    final mime = _pickMime();
    if (mime == null || frames.isEmpty) {
      throw StateError('This browser cannot record video');
    }
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = _width
      ..height = _height;
    final ctx = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
    ctx.fillStyle = '#1b1411'.toJS;
    ctx.fillRect(0, 0, _width, _height);

    final recorder = web.MediaRecorder(
      canvas.captureStream(30),
      web.MediaRecorderOptions(mimeType: mime, videoBitsPerSecond: 4000000),
    );
    final chunks = <web.Blob>[];
    recorder.ondataavailable = ((web.BlobEvent e) {
      if (e.data.size > 0) chunks.add(e.data);
    }).toJS;
    final stopped = Completer<void>();
    recorder.onstop = ((web.Event _) {
      if (!stopped.isCompleted) stopped.complete();
    }).toJS;

    recorder.start();
    try {
      for (var i = 0; i < frames.length; i++) {
        final bytes = await frames[i].load();
        final blob = web.Blob(
          [bytes.toJS].toJS,
          web.BlobPropertyBag(type: 'image/jpeg'),
        );
        final bitmap = await web.window.createImageBitmap(blob).toDart;
        _draw(ctx, bitmap, showLabel ? frames[i].label : null);
        bitmap.close();
        onProgress?.call(i + 1, frames.length);
        // The last photo stays a little longer.
        await Future<void>.delayed(
          Duration(
            milliseconds: i == frames.length - 1 ? frameMs + 600 : frameMs,
          ),
        );
      }
    } finally {
      if (recorder.state != 'inactive') recorder.stop();
    }
    await stopped.future.timeout(const Duration(seconds: 15));

    final base = mime.split(';').first;
    final out = web.Blob(chunks.toJS, web.BlobPropertyBag(type: base));
    final bytes = (await out.arrayBuffer().toDart).toDart.asUint8List();
    return TimelapseResult(bytes, base, base == 'video/mp4' ? 'mp4' : 'webm');
  }

  /// The photo fills the frame (cropped to fit); the age sits in a pill below.
  void _draw(
    web.CanvasRenderingContext2D ctx,
    web.ImageBitmap img,
    String? label,
  ) {
    ctx.fillStyle = '#1b1411'.toJS;
    ctx.fillRect(0, 0, _width, _height);
    final scale = (_width / img.width) > (_height / img.height)
        ? _width / img.width
        : _height / img.height;
    final w = img.width * scale;
    final h = img.height * scale;
    ctx.drawImage(img, (_width - w) / 2, (_height - h) / 2, w, h);
    if (label == null || label.isEmpty) return;

    ctx.font = '600 40px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    final textWidth = ctx.measureText(label).width;
    final pillW = textWidth + 64;
    const pillH = 72.0;
    final x = (_width - pillW) / 2;
    const y = _height - 56 - pillH;
    ctx.fillStyle = 'rgba(0,0,0,0.55)'.toJS;
    ctx.beginPath();
    try {
      ctx.roundRect(x, y, pillW, pillH, 36.toJS);
    } catch (_) {
      ctx.rect(x, y, pillW, pillH);
    }
    ctx.fill();
    ctx.fillStyle = '#ffffff'.toJS;
    ctx.fillText(label, _width / 2, y + pillH / 2 + 2);
  }

  @override
  Future<void> save(TimelapseResult result, String fileName) async {
    final blob = web.Blob(
      [result.bytes.toJS].toJS,
      web.BlobPropertyBag(type: result.mime),
    );
    final url = web.URL.createObjectURL(blob);
    final a = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName;
    web.document.body!.append(a);
    a.click();
    a.remove();
    Future<void>.delayed(const Duration(seconds: 30), () {
      web.URL.revokeObjectURL(url);
    });
  }
}

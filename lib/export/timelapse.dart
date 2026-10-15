import 'dart:typed_data';

/// One picture in the video: its label ("2 weeks, 2 days") and a way to load
/// the photo only when its turn comes (a long timeline would not fit in memory
/// all at once).
class TimelapseFrame {
  const TimelapseFrame(this.label, this.load);
  final String label;
  final Future<Uint8List> Function() load;
}

/// How long each photo stays on screen.
enum TimelapseSpeed {
  fast('Fast', 250),
  normal('Normal', 500),
  slow('Slow', 1000);

  const TimelapseSpeed(this.label, this.frameMs);
  final String label;
  final int frameMs;
}

/// The finished video.
class TimelapseResult {
  const TimelapseResult(this.bytes, this.mime, this.extension);
  final Uint8List bytes;
  final String mime;
  final String extension;
}

/// Makes the video in the browser and saves it as a download.
abstract class TimelapseExporter {
  /// False where videos cannot be made (tests on the VM, other platforms).
  bool get supported;

  Future<TimelapseResult> make(
    List<TimelapseFrame> frames, {
    required int frameMs,
    bool showLabel = true,
    void Function(int done, int total)? onProgress,
  });

  /// Hands the video to the browser as a file download.
  Future<void> save(TimelapseResult result, String fileName);
}

/// "Luna-timelapse.mp4": safe for any file system.
String timelapseFileName(String babyName, String extension) {
  final clean = babyName
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '${clean.isEmpty ? 'baby' : clean}-timelapse.$extension';
}

/// About how long the video will be, in seconds (the last photo stays a bit
/// longer).
int timelapseSeconds(int photos, TimelapseSpeed speed) =>
    ((photos * speed.frameMs + 600) / 1000).ceil();

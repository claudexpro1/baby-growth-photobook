import 'timelapse.dart';

TimelapseExporter createTimelapseExporter() => _NoVideo();

/// Used where the app cannot make videos.
class _NoVideo implements TimelapseExporter {
  @override
  bool get supported => false;
  @override
  Future<TimelapseResult> make(
    List<TimelapseFrame> frames, {
    required int frameMs,
    bool showLabel = true,
    void Function(int done, int total)? onProgress,
  }) => throw UnsupportedError('No video here');
  @override
  Future<void> save(TimelapseResult result, String fileName) =>
      throw UnsupportedError('No video here');
}

/// Outside the browser (tests) the app is never "installed".
bool isInstalledApp() => false;

String userAgent() => '';

int touchPoints() => 0;

/// The browser's own one-tap install (Chrome on Android): never in tests.
bool canPromptInstall() => false;

Future<bool> promptInstall() async => false;

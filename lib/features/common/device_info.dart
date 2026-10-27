/// What the visitor is browsing with, read from the user-agent string.
enum Os { ios, android, other }

enum Browser { safari, chrome, firefox, edge, samsung, inApp, other }

class DeviceInfo {
  const DeviceInfo(this.os, this.browser);
  final Os os;
  final Browser browser;

  bool get isPhone => os != Os.other;
}

/// [touchPoints] tells an iPad (which pretends to be a Mac) from a real Mac.
DeviceInfo parseDevice(String ua, {int touchPoints = 0}) {
  final ios =
      RegExp(r'iPhone|iPad|iPod').hasMatch(ua) ||
      (ua.contains('Macintosh') && touchPoints > 1);
  final android = ua.contains('Android');
  final os = ios
      ? Os.ios
      : android
      ? Os.android
      : Os.other;
  // Browsers built into other apps (Instagram, Facebook, WhatsApp links, the
  // Google app...) cannot add a page to the home screen.
  final inApp = RegExp(
    r'FBAN|FBAV|FB_IAB|Instagram|Line/|MicroMessenger|Snapchat|TikTok|'
    r'musical_ly|Pinterest|LinkedInApp|Twitter|GSA/|; wv\)',
  ).hasMatch(ua);
  if (os != Os.other && inApp) return DeviceInfo(os, Browser.inApp);
  Browser browser;
  if (ios) {
    browser = ua.contains('CriOS')
        ? Browser.chrome
        : ua.contains('FxiOS')
        ? Browser.firefox
        : ua.contains('EdgiOS')
        ? Browser.edge
        : ua.contains('OPiOS') || ua.contains('OPT/')
        ? Browser.other
        : ua.contains('Safari')
        ? Browser.safari
        : Browser.inApp; // a WebView: no "Safari" token
  } else if (android) {
    browser = ua.contains('SamsungBrowser')
        ? Browser.samsung
        : ua.contains('Firefox')
        ? Browser.firefox
        : ua.contains('EdgA')
        ? Browser.edge
        : ua.contains('OPR/')
        ? Browser.other
        : ua.contains('Chrome')
        ? Browser.chrome
        : Browser.other;
  } else {
    browser = Browser.other;
  }
  return DeviceInfo(os, browser);
}

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// True when the page runs from the home-screen icon (installed), not in a
/// browser tab. iPhone reports it with `navigator.standalone`, others with the
/// `display-mode: standalone` media query.
bool isInstalledApp() {
  try {
    if (web.window.matchMedia('(display-mode: standalone)').matches) {
      return true;
    }
    final standalone = (web.window.navigator as JSObject).getProperty(
      'standalone'.toJS,
    );
    return standalone.isA<JSBoolean>() && (standalone as JSBoolean).toDart;
  } catch (_) {
    return false;
  }
}

String userAgent() => web.window.navigator.userAgent;

int touchPoints() => web.window.navigator.maxTouchPoints;

/// Chrome on Android (and Edge/Samsung) hand the page an install prompt;
/// web/index.html keeps it in `window.__installPrompt`.
bool canPromptInstall() {
  try {
    final p = (web.window as JSObject).getProperty('__installPrompt'.toJS);
    return p.isA<JSObject>();
  } catch (_) {
    return false;
  }
}

/// Shows the browser's install dialog. True when the visitor accepted.
Future<bool> promptInstall() async {
  try {
    final window = web.window as JSObject;
    final p = window.getProperty('__installPrompt'.toJS);
    if (!p.isA<JSObject>()) return false;
    final event = p as JSObject;
    event.callMethod('prompt'.toJS);
    final choice =
        await (event.getProperty('userChoice'.toJS) as JSPromise).toDart;
    window.setProperty('__installPrompt'.toJS, null);
    final outcome = (choice as JSObject).getProperty('outcome'.toJS);
    return outcome.isA<JSString>() &&
        (outcome as JSString).toDart == 'accepted';
  } catch (_) {
    return false;
  }
}

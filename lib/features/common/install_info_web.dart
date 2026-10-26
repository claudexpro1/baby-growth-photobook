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

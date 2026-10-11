import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// One shared Google sign-in for Drive and Calendar. Each feature asks only
/// for its own narrow permission (scope) when it is first used.
class GoogleAuth {
  GoogleAuth._();

  // Build-time settings: --dart-define=GOOGLE_WEB_CLIENT_ID=...
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static Future<void>? _init;

  static Future<void> ensureInit() =>
      _init ??= GoogleSignIn.instance.initialize(
        serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
        clientId: kIsWeb
            ? (_webClientId.isEmpty ? null : _webClientId)
            : (_iosClientId.isEmpty ? null : _iosClientId),
      );

  /// Shows Google's permission screen for [scopes] (needs a user tap on web).
  static Future<void> authorize(List<String> scopes) async {
    await ensureInit();
    await GoogleSignIn.instance.authorizationClient.authorizeScopes(scopes);
  }

  /// Authorization headers if the user already allowed [scopes]; when
  /// [prompt] is true Google's screen may open. Null when not allowed.
  static Future<Map<String, String>?> headers(
    List<String> scopes, {
    required bool prompt,
  }) async {
    await ensureInit();
    return GoogleSignIn.instance.authorizationClient.authorizationHeaders(
      scopes,
      promptIfNecessary: prompt,
    );
  }
}

/// HTTP client that adds the user's Google authorization to every request.
class GoogleAuthClient extends http.BaseClient {
  GoogleAuthClient(this._headers);
  final Future<Map<String, String>> Function() _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers.addAll(await _headers());
    return _inner.send(request);
  }
}

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
  /// A remembered token that Google no longer accepts (expired early, or the
  /// app's access was removed) is dropped first, so the window opens right
  /// now, inside the tap, instead of failing later.
  static Future<void> authorize(List<String> scopes) async {
    await ensureInit();
    final client = GoogleSignIn.instance.authorizationClient;
    final cached = await client.authorizationHeaders(
      scopes,
      promptIfNecessary: false,
    );
    final token = cached?['Authorization']?.replaceFirst('Bearer ', '');
    if (token != null && !await tokenStillWorks(token)) {
      await forget(token);
    }
    await client.authorizeScopes(scopes);
  }

  /// Asks Google whether [token] is still valid. Anything unclear counts as
  /// valid, so a network hiccup never forces a new sign-in.
  static Future<bool> tokenStillWorks(
    String token, {
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    try {
      final r = await c.get(
        Uri.https('oauth2.googleapis.com', '/tokeninfo', {
          'access_token': token,
        }),
      );
      return r.statusCode != 400 && r.statusCode != 401;
    } catch (_) {
      return true;
    }
  }

  /// Drops a token Google refused, so the next request asks for a new one.
  static Future<void> forget(String token) async {
    await ensureInit();
    await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(
      accessToken: token,
    );
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

/// Google refused the saved sign-in and a new one could not be started.
class GoogleReauthFailed implements Exception {
  const GoogleReauthFailed(this.cause);
  final Object cause;
  @override
  String toString() => 'GoogleReauthFailed($cause)';
}

/// HTTP client that adds the user's Google authorization to every request.
/// When Google answers 401 (the token expired or was revoked early) it forgets
/// that token and, for ordinary requests, asks for a fresh one and tries once
/// more, so one tap is enough.
class GoogleAuthClient extends http.BaseClient {
  GoogleAuthClient(
    this._headers, {
    http.Client? inner,
    Future<void> Function(String token)? forget,
  }) : _inner = inner ?? http.Client(),
       _forget = forget ?? GoogleAuth.forget;

  final Future<Map<String, String>> Function() _headers;
  final http.Client _inner;
  final Future<void> Function(String token) _forget;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final first = await _headers();
    request.headers.addAll(first);
    final res = await _inner.send(request);
    if (res.statusCode != 401) return res;

    final bytes = await res.stream.toBytes();
    http.StreamedResponse again() => http.StreamedResponse(
      http.ByteStream.fromBytes(bytes),
      res.statusCode,
      headers: res.headers,
      request: res.request,
      reasonPhrase: res.reasonPhrase,
    );

    final stale = first['Authorization']?.replaceFirst('Bearer ', '');
    if (stale != null) {
      try {
        await _forget(stale);
      } catch (_) {
        /* nothing cached to forget */
      }
    }
    if (request is! http.Request) return again();
    try {
      final fresh = await _headers();
      final retry = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..headers.addAll(fresh)
        ..bodyBytes = request.bodyBytes;
      return await _inner.send(retry);
    } catch (e) {
      throw GoogleReauthFailed(e);
    }
  }
}

import 'package:baby_growth_photobook/data/google_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('a 401 forgets the token, asks again and retries once', () async {
    var tokens = 0;
    final forgotten = <String>[];
    final seen = <String?>[];
    final client = GoogleAuthClient(
      () async => {'Authorization': 'Bearer t${++tokens}'},
      forget: (t) async => forgotten.add(t),
      inner: MockClient((r) async {
        seen.add(r.headers['Authorization']);
        return r.headers['Authorization'] == 'Bearer t1'
            ? http.Response('{"error":"Invalid Credentials"}', 401)
            : http.Response('{"ok":true}', 200);
      }),
    );
    final res = await client.post(Uri.parse('https://x.test/a'), body: 'hello');
    expect(res.statusCode, 200);
    expect(forgotten, ['t1']);
    expect(seen, ['Bearer t1', 'Bearer t2']);
  });

  test('if no fresh token can be had, it says so', () async {
    var tokens = 0;
    final client = GoogleAuthClient(
      () async {
        if (++tokens > 1) throw StateError('needs a tap');
        return {'Authorization': 'Bearer t1'};
      },
      forget: (t) async {},
      inner: MockClient(
        (r) async => http.Response('{"error":"Invalid Credentials"}', 401),
      ),
    );
    expect(
      client.get(Uri.parse('https://x.test/a')),
      throwsA(isA<GoogleReauthFailed>()),
    );
  });

  test(
    'token check: refused tokens are stale, doubt counts as valid',
    () async {
      http.Client answers(int code) => MockClient((r) async {
        expect(r.url.host, 'oauth2.googleapis.com');
        return http.Response('{}', code);
      });
      expect(
        await GoogleAuth.tokenStillWorks('t', client: answers(200)),
        isTrue,
      );
      expect(
        await GoogleAuth.tokenStillWorks('t', client: answers(400)),
        isFalse,
      );
      expect(
        await GoogleAuth.tokenStillWorks('t', client: answers(401)),
        isFalse,
      );
      expect(
        await GoogleAuth.tokenStillWorks('t', client: answers(500)),
        isTrue,
      );
      final broken = MockClient((r) async => throw Exception('offline'));
      expect(await GoogleAuth.tokenStillWorks('t', client: broken), isTrue);
    },
  );

  test('other answers pass through untouched', () async {
    var calls = 0;
    final client = GoogleAuthClient(
      () async => {'Authorization': 'Bearer t1'},
      forget: (t) async => fail('must not forget'),
      inner: MockClient((r) async {
        calls++;
        return http.Response('nope', 404);
      }),
    );
    expect((await client.get(Uri.parse('https://x.test/a'))).statusCode, 404);
    expect(calls, 1);
  });
}

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

  test('if no fresh token can be had, the original 401 comes back', () async {
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
    final res = await client.get(Uri.parse('https://x.test/a'));
    expect(res.statusCode, 401);
    expect(res.body, contains('Invalid Credentials'));
  });

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

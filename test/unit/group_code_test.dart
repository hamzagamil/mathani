// Reading a group khatma's code or link (specs/014 research R16, Story 5 scenario 18).
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/khatma/group/group_code.dart';
import 'package:mathani/features/khatma/group/group_key.dart';

void main() {
  const code = 'ABCD2345EFGH6789';

  test('a code, with or without hyphens and spaces, in any case', () {
    expect(GroupCode.parse(code), code);
    expect(GroupCode.parse('abcd-2345-efgh-6789'), code);
    expect(GroupCode.parse(' ABCD 2345 EFGH 6789 '), code);
  });

  test('a whole link', () {
    expect(GroupCode.parse('https://get.mthani.app/k/$code'), code);
    expect(GroupCode.parse('Take your part: https://get.mthani.app/k/abcd2345efgh6789'), code);
    // The same link on the main domain (it opens the app, or redirects to the web app).
    expect(GroupCode.parse('https://mthani.app/k/$code'), code);
    expect(GroupCode.parse('https://www.mthani.app/k/$code'), code);
  });

  test('Crockford look-alikes are read as digits', () {
    expect(GroupCode.parse('ABCD2345EFGH678O'), 'ABCD2345EFGH6780');
    expect(GroupCode.parse('ABCD2345EFGH678I'), 'ABCD2345EFGH6781');
  });

  test('anything else is not a code', () {
    for (final t in ['', 'hello', 'ABCD2345EFGH678', 'ABCD2345EFGH67890', 'ABCD2345EFGH678U']) {
      expect(GroupCode.parse(t), isNull, reason: t);
    }
  });

  test('format and link', () {
    expect(GroupCode.format(code), 'ABCD-2345-EFGH-6789');
    expect(GroupCode.linkOf(code), 'https://get.mthani.app/k/$code');
  });

  test('a device key is 43 base64url characters', () async {
    final k = newDeviceKey();
    expect(k, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    expect(newDeviceKey(), isNot(k));
    final store = MemoryKeyStore();
    expect(await store.read(), isNull);
    final made = await store.create();
    expect(await store.create(), made);
  });
}

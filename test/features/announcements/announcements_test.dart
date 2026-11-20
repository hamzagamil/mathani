import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/announcements/announcements.dart';

class FakePlatform implements AnnouncementsPlatform {
  bool available = true;
  int starts = 0, permissionRequests = 0;
  final topics = <String>{};
  final links = StreamController<String>.broadcast();

  @override
  Future<bool> start() async {
    starts++;
    return available;
  }

  @override
  Future<void> subscribe(Set<String> t) async => topics.addAll(t);
  @override
  Future<void> unsubscribe(Set<String> t) async => topics.removeAll(t);
  @override
  Future<void> requestPermission() async => permissionRequests++;
  @override
  Stream<String> get openedLinks => links.stream;
}

void main() {
  late FakePlatform platform;
  late bool enabled;
  late String language;
  String? stored;
  late List<String> opened;

  Announcements make() => Announcements(
    platform: platform,
    enabled: () => enabled,
    language: () => language,
    readTopics: () async => stored,
    writeTopics: (t) async => stored = t,
    onLink: opened.add,
  );

  setUp(() {
    platform = FakePlatform();
    enabled = true;
    language = 'ar';
    stored = null;
    opened = [];
  });

  test('on: subscribes to everyone and the app language, without asking permission', () async {
    await make().start();
    expect(platform.topics, {'all', 'lang_ar'});
    expect(stored, 'all,lang_ar');
    expect(platform.permissionRequests, 0);
  });

  test('a language change moves the language topic', () async {
    final a = make();
    await a.start();
    language = 'en';
    a.preferencesChanged();
    await a.sync();
    expect(platform.topics, {'all', 'lang_en'});
  });

  test(
    'off unsubscribes everything; turning on again asks for permission',
    () async {
      final a = make();
      await a.start();
      enabled = false;
      a.preferencesChanged();
      await a.sync();
      expect(platform.topics, isEmpty);
      expect(stored, '');
      enabled = true;
      a.preferencesChanged();
      await a.sync();
      expect(platform.permissionRequests, 1);
      expect(platform.topics, {'all', 'lang_ar'});
    },
  );

  test(
    'off from the first launch never starts the push service (FR-017)',
    () async {
      enabled = false;
      await make().start();
      expect(platform.starts, 0);
    },
  );

  test('off at launch after being on: old topics are removed', () async {
    stored = 'all,lang_en';
    platform.topics.addAll({'all', 'lang_en'});
    enabled = false;
    await make().start();
    expect(platform.topics, isEmpty);
  });

  test('unchanged preferences do nothing (every page turn notifies)', () async {
    final a = make();
    await a.start();
    final starts = platform.starts;
    for (var i = 0; i < 10; i++) {
      a.preferencesChanged();
    }
    await a.sync();
    expect(platform.starts, starts + 1); // only the explicit sync above
  });

  test(
    'unavailable (not configured): nothing is stored, retried later',
    () async {
      platform.available = false;
      final a = make();
      await a.start();
      expect(stored, isNull);
      platform.available = true;
      await a.sync();
      expect(stored, 'all,lang_ar');
    },
  );

  test('only Mathani https links are opened', () async {
    await make().start();
    platform.links
      ..add('https://mthani.app/k/abc123')
      ..add('https://GET.mthani.app/')
      ..add('http://mthani.app/k/x')
      ..add('https://evil.example/k/x')
      ..add('not a link');
    await Future<void>.delayed(Duration.zero);
    expect(opened, ['https://mthani.app/k/abc123', 'https://get.mthani.app/']);
  });

  test('mathaniLink', () {
    expect(mathaniLink(null), isNull);
    expect(mathaniLink('https://www.mthani.app/x'), 'https://www.mthani.app/x');
    expect(mathaniLink('https://mthani.app.evil.example/'), isNull);
  });
}

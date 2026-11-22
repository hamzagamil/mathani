import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/khatma/group/group_code.dart';
import 'package:mathani/features/khatma/group/group_link_host.dart';
import 'package:mathani/features/widgets/widget_link_host.dart';

class _Source implements LinkSource {
  _Source(this.first);
  final String? first;
  int takes = 0;
  final controller = StreamController<String>.broadcast();

  @override
  Future<String?> takeLink() async {
    takes++;
    return takes == 1 ? first : null;
  }

  @override
  Stream<String> get links => controller.stream;
}

// specs/017 contracts/widget-surfaces.md › Links.
void main() {
  group('WidgetLink.parse', () {
    test('the four links', () {
      expect(WidgetLink.parse('mathani-widget://prayer'), isA<PrayerLink>());
      expect(WidgetLink.parse('mathani-widget://khatma'), isA<KhatmaLink>());
      expect(WidgetLink.parse('mathani-widget://khatma/read'), isA<KhatmaReadLink>());
      expect(
        WidgetLink.parse('mathani-widget://mushaf/23'),
        isA<MushafLink>().having((l) => l.page, 'page', 23),
      );
      expect(WidgetLink.parse('mathani-widget://mushaf/604'), isA<MushafLink>());
    });

    test('anything else is not a widget link', () {
      for (final bad in [
        'mathani-widget://mushaf/0',
        'mathani-widget://mushaf/605',
        'mathani-widget://mushaf/x',
        'mathani-widget://mushaf/023',
        'mathani-widget://mushaf',
        'mathani-widget://khatma/edit',
        'mathani-widget://unknown',
        'https://get.mthani.app/k/ABCD-EFGH-JKMN-PQRS',
        'mathani://prayer',
        '',
        '%%%',
      ]) {
        expect(WidgetLink.parse(bad), isNull, reason: bad);
      }
    });

    test('group links never read a widget link as a code', () {
      expect(GroupCode.parse('mathani-widget://khatma/read'), isNull);
      expect(GroupCode.parse('mathani-widget://mushaf/23'), isNull);
    });
  });

  group('LinkSplitter', () {
    test('the launch link goes to its side only, and is taken from the platform once', () async {
      final source = _Source('mathani-widget://prayer');
      final split = LinkSplitter(source);
      expect(await split.others.takeLink(), isNull);
      expect(await split.widgets.takeLink(), 'mathani-widget://prayer');
      expect(await split.widgets.takeLink(), isNull);
      expect(source.takes, 1);
    });

    test('a group launch link reaches the group side', () async {
      final split = LinkSplitter(_Source('https://get.mthani.app/k/ABCDEFGHJKMNPQRS'));
      expect(await split.widgets.takeLink(), isNull);
      expect(await split.others.takeLink(), 'https://get.mthani.app/k/ABCDEFGHJKMNPQRS');
    });

    test('running links are filtered by side', () async {
      final source = _Source(null);
      final split = LinkSplitter(source);
      final widgets = <String>[], others = <String>[];
      split.widgets.links.listen(widgets.add);
      split.others.links.listen(others.add);
      source.controller
        ..add('mathani-widget://mushaf/5')
        ..add('https://get.mthani.app/k/ABCDEFGHJKMNPQRS');
      await Future<void>.delayed(Duration.zero);
      expect(widgets, ['mathani-widget://mushaf/5']);
      expect(others, ['https://get.mthani.app/k/ABCDEFGHJKMNPQRS']);
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/l10n/app_localizations.dart';
import 'package:mathani/app/theme/app_theme.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/recitation/reciter_sheet.dart';

import '../support/harness.dart';

/// The searchable reciter list (specs/006 T013, contracts/reciter-catalogue.md › Reciter list),
/// with the catalogue's real rows from tool/recitations.json.
void main() {
  final reciters = [
    for (final j in jsonDecode(File('tool/recitations.json').readAsStringSync()) as List)
      Reciter(
        id: j['id'] as String,
        nameAr: j['name_ar'] as String,
        nameEn: j['name_en'] as String,
        shortAr: j['short_ar'] as String,
        shortEn: j['short_en'] as String,
        style: RecitationStyle.parse(j['style'] as String),
        baseUrl: j['base_url'] as String,
        mirrorUrl: j['mirror_url'] as String?,
        bitrateKbps: j['bitrate_kbps'] as int,
        sort: j['sort'] as int,
        source: RecitationSource.parse(j['source'] as String),
        filePattern: j['file_pattern'] as String,
        basmalaInAyah1: j['basmala_in_ayah1'] == 1,
      ),
  ];

  Iterable<String> ids(String query) => [
        for (final r in reciters)
          if (reciterMatches(r, query)) r.id,
      ];

  test('search: Arabic with or without ال and letter forms, English ignoring case', () {
    expect(ids('عفاسي'), ['alafasy']);
    expect(ids('العفاسي'), ['alafasy']);
    expect(ids('alafasy'), ['alafasy']);
    expect(ids('ALAFASY'), ['alafasy']);
    expect(ids('الحصري'), unorderedEquals(['husary', 'husary_mujawwad', 'husary_muallim']));
    expect(ids('حصري'), unorderedEquals(['husary', 'husary_mujawwad', 'husary_muallim']));
    expect(ids('husary'), hasLength(3));
    expect(ids('ابو بكر'), ['shatri'], reason: 'أ and ا match');
    expect(ids('عبد الباسط'), unorderedEquals(['abdulbasit_murattal', 'abdulbasit_mujawwad']));
    expect(ids('zzz'), isEmpty);
  });

  test('sorted by name in the interface language, one reciter\'s styles in catalogue order', () {
    final ar = sortedReciters(reciters, arabic: true);
    final husary = [for (final r in ar) if (r.nameAr == 'محمود خليل الحصري') r.id];
    expect(husary, ['husary', 'husary_mujawwad', 'husary_muallim']);
    final en = sortedReciters(reciters, arabic: false);
    expect(en.first.nameEn.toLowerCase().compareTo(en.last.nameEn.toLowerCase()), lessThan(0));
  });

  Future<void> pumpList(WidgetTester tester, {required Locale locale, String? selected}) async {
    await tester.runAsync(loadAppFonts);
    tester.view.physicalSize = const Size(780, 1690);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(builder: (context) {
          final l10n = AppLocalizations.of(context);
          return ReciterList(
            reciters: reciters,
            selectedId: selected,
            rowBuilder: (context, r, isSelected) => ListTile(
              selected: isSelected,
              title: Text(r.name(arabic: locale.languageCode == 'ar')),
              subtitle: Text(styleLabel(l10n, r.style)),
            ),
          );
        }),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('filters as the reader types, and shows a message when nothing matches',
      (tester) async {
    await pumpList(tester, locale: const Locale('ar'), selected: 'husary');
    await tester.enterText(find.byType(TextField), 'عفاسي');
    await tester.pump();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('مشاري راشد العفاسي'), findsOneWidget);
    expect(find.text('مرتّل'), findsOneWidget, reason: 'the style label is shown');

    await tester.enterText(find.byType(TextField), 'لا أحد');
    await tester.pump();
    expect(find.byType(ListTile), findsNothing);
    expect(find.text('لا يوجد قارئ بهذا الاسم'), findsOneWidget);
  });

  testWidgets('opens with the chosen reciter in view; rows are at least 48 dp high',
      (tester) async {
    await pumpList(tester, locale: const Locale('en'), selected: 'dossari');
    final chosen = find.ancestor(of: find.text('Yasser Al-Dosari'), matching: find.byType(ListTile));
    expect(chosen, findsOneWidget, reason: 'built, so scrolled into view');
    expect(tester.widget<ListTile>(chosen).selected, isTrue);
    for (final tile in tester.elementList(find.byType(ListTile))) {
      expect(tile.size!.height, greaterThanOrEqualTo(48));
    }
    expect(MathaniColors.of(tester.element(chosen)), isNotNull);
  });
}

// Settings › Recitations › Downloads, the Surahs index marks and the download preconditions
// (specs/004 contracts/recitation-ui.md › Downloads screen, Index › Surahs;
// contracts/audio-storage.md › Preconditions).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/recitation/ayah_fetcher.dart';
import 'package:mathani/features/recitation/download_queue.dart';
import 'package:mathani/features/recitation/downloads_screen.dart';
import 'package:mathani/features/recitation/recitation_controller.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_recitation.dart';
import '../support/harness.dart';

void main() {
  late ReaderController reader;
  late RecitationController recitation;
  late AyahFetcher fetcher;
  late Directory temp;
  var network = 'unmetered';
  var free = 1 << 40;

  Future<void> settle(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> writeValid(File f, int bytes) async {
    await f.parent.create(recursive: true);
    await f.writeAsBytes(Uint8List(bytes));
  }

  /// Al-Kawthar complete and Al-Ikhlas partly downloaded for Al-Husary.
  Future<void> seedDownloads() async {
    final quran = reader.quran;
    for (final (surah, count) in [(108, 3), (112, 1)]) {
      final sizes = await quran.recordingBytes('husary', surah);
      for (var a = 1; a <= count; a++) {
        await writeValid(await fetcher.downloadFile('husary', surah, a), sizes[a - 1]);
      }
    }
    await writeValid(await fetcher.basmalaFile('husary'),
        (await quran.recordingBytes('husary', 1)).first);
  }

  Future<void> pumpApp(WidgetTester tester, {bool seed = true}) async {
    network = 'unmetered';
    free = 1 << 40;
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
      temp = Directory.systemTemp.createTempSync('mathani_dl_screen');
      fetcher = AyahFetcher(
        recordingSize: (r, s, a) async => (await reader.quran.recordingBytes(r, s))[a - 1],
        cacheRoot: () async => Directory('${temp.path}/cache'),
        supportRoot: () async => Directory('${temp.path}/support'),
      );
      // Catalogue sizes come from the database: load them in real async (they are cached).
      for (final r in ['husary', 'minshawy']) {
        for (var s = 1; s <= 114; s++) {
          await reader.quran.recordingBytes(r, s);
        }
      }
      if (seed) await seedDownloads();
    });
    reader.updatePreferences(reader.preferences.copyWith(language: LanguagePref.ar));
    recitation =
        RecitationController(reader: reader, fetcher: fetcher, engine: () => FakeAudioEngine());
    tester.view.physicalSize = const Size(780, 1690);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('app.mathani/device'),
        (call) async => switch (call.method) {
              'networkState' => network,
              'freeBytes' => free,
              _ => null,
            });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(const MethodChannel('app.mathani/device'), null);
    });
    await tester.pumpWidget(MathaniApp(controller: reader, recitation: recitation));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    recitation.dispose();
    await tester.runAsync(() async {
      reader.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      temp.deleteSync(recursive: true);
    });
    await tester.pump(const Duration(seconds: 2));
  }

  /// Runs the disk scan in real async: one started under the fake test clock cannot finish.
  Future<void> scan(WidgetTester tester) =>
      tester.runAsync(() => recitation.downloads.ensureScanned());

  Future<void> openDownloads(WidgetTester tester) async {
    await tapToolbar(tester, MathaniIcons.settings);
    await settle(tester);
    await tester.scrollUntilVisible(find.text('التنزيلات'), 200);
    await tester.tap(find.text('التنزيلات'));
    await tester.pump(); // the first frame, before the disk scan
  }

  testWidgets('renders at once with placeholders while the disk scan runs', (tester) async {
    await pumpApp(tester);
    await openDownloads(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(recitation.downloads.scanned.value, isFalse);
    expect(find.byType(DownloadsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('downloads-skeleton')), findsOneWidget,
        reason: 'the screen never waits for the scan (Principle III)');
    await finish(tester);
  });

  testWidgets('lists downloads by reciter after the scan', (tester) async {
    await pumpApp(tester);
    await scan(tester);
    await openDownloads(tester);
    await settle(tester);
    expect(find.byType(DownloadsScreen), findsOneWidget);
    expect(find.text('محمود خليل الحصري'), findsOneWidget);
    expect(find.text('١٠٨ · سورة الكوثر'), findsOneWidget);
    expect(find.text('١١٢ · سورة الإخلاص'), findsOneWidget);
    expect(find.textContaining('متوقف — استئناف'), findsOneWidget, reason: 'Al-Ikhlas is partial');
    expect(find.byIcon(MathaniIcons.downloaded), findsOneWidget, reason: 'Al-Kawthar is complete');
    await finish(tester);
  });

  testWidgets('deleting updates the total within 1 s; deleting all shows the empty state',
      (tester) async {
    await pumpApp(tester);
    await scan(tester);
    await openDownloads(tester);
    await settle(tester);
    final before = recitation.downloads.savedBytes('husary');

    await tester.tap(find.byTooltip('خيارات السورة').first);
    await settle(tester, 2);
    await tester.tap(find.text('حذف التنزيل').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(recitation.downloads.savedBytes('husary'), lessThan(before), reason: 'SC-012');
    await settle(tester);

    await tester.tap(find.text('حذف الكل'));
    await settle(tester, 2);
    await tester.tap(find.text('حذف الكل').last); // confirm
    await settle(tester);
    expect(find.text('لم تنزّل أي سورة بعد. نزّل سورة من فهرس السور.'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('preconditions: offline, not enough storage, and mobile data asks first',
      (tester) async {
    await pumpApp(tester, seed: false);
    final context = tester.element(find.byType(Scaffold).first);
    final queue = recitation.downloads;

    network = 'none';
    await tester.runAsync(() => startSurahDownload(context, queue, 'husary', 67));
    await settle(tester, 6);
    expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
    expect(queue.stateOf('husary', 67), isNull);

    network = 'unmetered';
    free = 1024; // far below the size + 50 MB
    await tester.runAsync(() => startSurahDownload(context, queue, 'husary', 67));
    await settle(tester, 6);
    expect(find.textContaining('المساحة غير كافية'), findsOneWidget);
    expect(queue.stateOf('husary', 67), isNull);

    free = 1 << 40;
    network = 'metered';
    // The dialog waits for an answer: start it without awaiting.
    late Future<void> pending;
    await tester.runAsync(() async {
      pending = startSurahDownload(context, queue, 'husary', 67);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester, 3);
    expect(find.textContaining('أنت على بيانات الجوال'), findsOneWidget);
    await tester.tap(find.text(MaterialLocalizations.of(context).cancelButtonLabel));
    await settle(tester, 2);
    await tester.runAsync(() => pending);
    expect(queue.stateOf('husary', 67), isNull, reason: 'cancel does nothing');
    await finish(tester);
  });

  testWidgets('the Surahs index marks surahs downloaded for the chosen reciter only',
      (tester) async {
    await pumpApp(tester);
    await scan(tester);
    await tapToolbar(tester, MathaniIcons.index);
    await settle(tester);
    await tester.scrollUntilVisible(find.text('سورة الكوثر'), 600);
    await settle(tester, 2);
    expect(find.descendant(of: find.ancestor(of: find.text('سورة الكوثر'), matching: find.byType(ListTile)),
        matching: find.byIcon(MathaniIcons.downloaded)), findsOneWidget);
    expect(find.descendant(of: find.ancestor(of: find.text('سورة الإخلاص'), matching: find.byType(ListTile)),
        matching: find.byIcon(MathaniIcons.downloaded)), findsNothing, reason: 'partial: no mark');

    await tester.runAsync(() async {
      reader.updatePreferences(reader.preferences.copyWith(reciter: 'minshawy'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    await tapToolbar(tester, MathaniIcons.index);
    await settle(tester);
    await tester.scrollUntilVisible(find.text('سورة الكوثر'), 600);
    await settle(tester, 2);
    expect(find.byIcon(MathaniIcons.downloaded), findsNothing, reason: 'not for El-Minshawi');
    await finish(tester);
  });

  testWidgets('Clear recent recitations empties the cache and keeps downloads (FR-021, FR-034)',
      (tester) async {
    await pumpApp(tester);
    await tester.runAsync(() async {
      await writeValid(await fetcher.cacheFile('husary', 2, 255), 300 * 1024);
    });
    await scan(tester);
    await tapToolbar(tester, MathaniIcons.settings);
    await settle(tester);
    await tester.scrollUntilVisible(find.text('مسح التلاوات المؤقتة'), 200);
    await settle(tester);
    expect(find.text('٣٠٠٫٠ ك.ب'), findsOneWidget);
    final downloadsBefore = recitation.downloads.savedBytes();

    await tester.tap(find.text('مسح التلاوات المؤقتة'));
    await settle(tester, 2);
    await tester.tap(find.text('مسح التلاوات المؤقتة').last); // confirm
    // Each file operation under the fake clock needs a real-time step and a pump.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.textContaining('تم تحرير'), findsOneWidget);
    expect(await tester.runAsync(() => fetcher.cacheBytes()), 0);
    expect(recitation.downloads.savedBytes(), downloadsBefore);
    expect(await tester.runAsync(() async => (await fetcher.downloadFile('husary', 108, 1)).existsSync()),
        isTrue);
    await finish(tester);
  });
}

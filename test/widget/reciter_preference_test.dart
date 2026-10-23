import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/data/user_repository.dart';

import '../support/harness.dart';

/// The chosen reciter (specs/004 FR-004, T011): default, persisted, and an unknown id falls back.
void main() {
  testWidgets('the reciter defaults to Al-Husary, persists, and an unknown id falls back',
      (tester) async {
    final reader = (await tester.runAsync(openTestReader))!;
    final quran = reader.quran;

    expect([for (final r in quran.reciters) r.id], ['husary', 'minshawy']);
    expect(reader.preferences.reciter, 'husary');
    expect(quran.reciterOrDefault(reader.preferences.reciter)!.id, 'husary');

    reader.updatePreferences(reader.preferences.copyWith(reciter: 'minshawy'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    var reopened = (await tester.runAsync(UserRepository.open))!;
    var (_, prefs) = (await tester.runAsync(reopened.loadStartup))!;
    expect(prefs.reciter, 'minshawy');

    await tester.runAsync(
        () => reopened.savePreferences(prefs.copyWith(reciter: 'removed-in-a-later-release')));
    reopened = (await tester.runAsync(UserRepository.open))!;
    (_, prefs) = (await tester.runAsync(reopened.loadStartup))!;
    expect(quran.reciterOrDefault(prefs.reciter)!.id, Reciter.defaultId);
  });

  testWidgets('the catalogue has every ayah for every reciter', (tester) async {
    final quran = (await tester.runAsync(openTestReader))!.quran;
    for (final r in quran.reciters) {
      var total = 0;
      for (final s in quran.surahList) {
        final bytes = (await tester.runAsync(() => quran.recordingBytes(r.id, s.number)))!;
        expect(bytes, hasLength(s.ayahCount), reason: '${r.id} surah ${s.number}');
        expect(bytes.every((b) => b > 0), isTrue);
        total += bytes.length;
      }
      expect(total, 6236);
    }
    expect(quran.reciter('husary')!.urlFor(2, 255),
        'https://everyayah.com/data/Husary_64kbps/002255.mp3');
    // Al-Mulk download size: all 30 ayat plus the basmala (1:1).
    final ayat = (await tester.runAsync(() => quran.recordingBytes('husary', 67)))!;
    final basmala = (await tester.runAsync(() => quran.recordingBytes('husary', 1)))!.first;
    expect((await tester.runAsync(() => quran.surahDownloadBytes('husary', 67)))!,
        ayat.fold(0, (a, b) => a + b) + basmala);
    expect((await tester.runAsync(() => quran.surahDownloadBytes('husary', 9)))!,
        (await tester.runAsync(() => quran.recordingBytes('husary', 9)))!.fold(0, (a, b) => a + b));
  });
}

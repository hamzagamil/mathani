import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/recitation/recited_item.dart';

import '../support/harness.dart';

/// Item order (specs/004 data-model › Recited item order): every ayah once, in Mushaf order, with
/// the basmala before ayah 1 of every surah except Al-Fatiha and At-Tawbah.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecitedOrder order;

  setUpAll(() async {
    final reader = await openTestReader();
    final counts = [for (final s in reader.quran.surahList) s.ayahCount];
    order = RecitedOrder(ayahCount: (s) => counts[s - 1]);
  });

  RecitedItem ayah(int s, int a) => RecitedItem.ayah(s, a);

  test('next visits all 6,236 ayat once, in order, with 112 basmala items', () {
    var item = order.startItem(const AyahRef(1, 1));
    var ayat = 0, basmalas = 0;
    RecitedItem? previousAyah;
    final seen = <RecitedItem>{};
    for (RecitedItem? i = item; i != null; i = order.next(i)) {
      expect(seen.add(i), isTrue, reason: '$i visited twice');
      if (i.isBasmala) {
        basmalas++;
        expect(i.surah, isNot(anyOf(1, 9)));
        expect(order.next(i), ayah(i.surah, 1));
      } else {
        ayat++;
        if (previousAyah != null) expect(i.ref.compareTo(previousAyah.ref), greaterThan(0));
        previousAyah = i;
      }
      item = i;
    }
    expect(ayat, 6236);
    expect(basmalas, 112);
    expect(item, ayah(114, 6));
    expect(order.next(ayah(114, 6)), isNull);
  });

  test('basmala rules', () {
    expect(order.next(ayah(8, 75)), ayah(9, 1));
    expect(order.next(ayah(1, 7)), const RecitedItem.basmala(2));
    expect(order.next(const RecitedItem.basmala(2)), ayah(2, 1));
    expect(order.startItem(const AyahRef(2, 1)), const RecitedItem.basmala(2));
    expect(order.startItem(const AyahRef(1, 1)), ayah(1, 1));
    expect(order.startItem(const AyahRef(9, 1)), ayah(9, 1));
    expect(order.startItem(const AyahRef(2, 255)), ayah(2, 255));
  });

  test('previous skips basmala items and stops at 1:1', () {
    expect(order.previous(const RecitedItem.basmala(2)), ayah(1, 7));
    expect(order.previous(ayah(2, 1)), ayah(1, 7));
    expect(order.previous(ayah(9, 1)), ayah(8, 75));
    expect(order.previous(ayah(2, 2)), ayah(2, 1));
    expect(order.previous(ayah(1, 1)), ayah(1, 1));
    for (var s = 2; s <= 114; s++) {
      expect(order.previous(ayah(s, 1)).isBasmala, isFalse);
    }
  });

  test('a basmala item maps to ayah 1 of its surah', () {
    expect(const RecitedItem.basmala(67).ref, const AyahRef(67, 1));
    expect(const RecitedItem.basmala(67).isBasmala, isTrue);
    expect(ayah(67, 1).isBasmala, isFalse);
    expect(const RecitedItem.basmala(67), isNot(ayah(67, 1)));
  });
}

// What is being recited and in which order (specs/004-ayah-recitations/data-model.md ›
// Recited item order). Pure Dart: no Flutter imports, so it is unit tested without a device.
import '../../data/models.dart';

/// One unit of recitation: an ayah, or the basmala recited before ayah 1 of a surah.
class RecitedItem {
  const RecitedItem.ayah(this.surah, this.ayah) : assert(ayah >= 1);
  const RecitedItem.basmala(this.surah) : ayah = 0;

  final int surah;

  /// 1-based ayah number, or 0 for the basmala.
  final int ayah;

  bool get isBasmala => ayah == 0;

  /// The ayah this item belongs to: ayah 1 for a basmala. Used for the highlight anchor and
  /// navigation; the page a basmala sits on comes from `RecitationController.recitedPage`.
  AyahRef get ref => AyahRef(surah, isBasmala ? 1 : ayah);

  @override
  bool operator ==(Object other) =>
      other is RecitedItem && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);

  @override
  String toString() => isBasmala ? '$surah:basmala' : '$surah:$ayah';
}

/// Mushaf order of recited items.
class RecitedOrder {
  const RecitedOrder({required this.ayahCount});

  /// Number of ayat in a surah (1..114).
  final int Function(int surah) ayahCount;

  static bool hasBasmalaItem(int surah) => surah != 1 && surah != 9;

  /// Where a recitation that starts at [ref] begins: its basmala when [ref] is ayah 1 of a surah
  /// that has one (FR-008).
  RecitedItem startItem(AyahRef ref) => ref.ayah == 1 && hasBasmalaItem(ref.surah)
      ? RecitedItem.basmala(ref.surah)
      : RecitedItem.ayah(ref.surah, ref.ayah);

  /// The item after [item], or null after 114:6 (the end of the Quran).
  RecitedItem? next(RecitedItem item) {
    if (item.isBasmala) return RecitedItem.ayah(item.surah, 1);
    if (item.ayah < ayahCount(item.surah)) return RecitedItem.ayah(item.surah, item.ayah + 1);
    if (item.surah >= 114) return null;
    return startItem(AyahRef(item.surah + 1, 1));
  }

  /// The ayah before [item]. Never a basmala item; 1:1 stays on 1:1.
  RecitedItem previous(RecitedItem item) {
    if (!item.isBasmala && item.ayah > 1) return RecitedItem.ayah(item.surah, item.ayah - 1);
    if (item.surah == 1) return const RecitedItem.ayah(1, 1);
    return RecitedItem.ayah(item.surah - 1, ayahCount(item.surah - 1));
  }
}

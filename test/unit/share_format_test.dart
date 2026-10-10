import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/reader/ayah_actions.dart';

void main() {
  const baqarah = Surah(
    number: 2,
    nameAr: 'البقرة',
    nameTranslit: 'Al-Baqara',
    ayahCount: 286,
    revelation: Revelation.madani,
    startPage: 2,
  );
  Word w(int id, String text, {bool end = false}) =>
      Word(id: id, surah: 2, ayah: 255, position: id, text: text, isAyahEnd: end);
  final words = [w(1, 'ٱللَّهُ'), w(2, 'لَآ'), w(3, 'إِلَـٰهَ'), w(4, '٢٥٥', end: true)];

  test('Arabic: ornate brackets, surah name, Eastern Arabic ayah number (FR-021)', () {
    expect(
      formatAyahForShare(words, baqarah, 255, arabic: true),
      '﴿ٱللَّهُ لَآ إِلَـٰهَ﴾\nسورة البقرة: ٢٥٥',
    );
  });

  test('English: transliterated name and surah:ayah', () {
    expect(
      formatAyahForShare(words, baqarah, 255, arabic: false),
      '﴿ٱللَّهُ لَآ إِلَـٰهَ﴾\nSurah Al-Baqara 2:255',
    );
  });
}

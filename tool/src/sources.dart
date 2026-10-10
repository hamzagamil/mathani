// Shared helpers for the Quran data tools: source paths, checksums and Tanzil parsing.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

const sourcesDir = 'tool/sources';
const lockFile = 'tool/sources.lock.json';
const outputDb = 'assets/db/quran.db';
const outputVersion = 'assets/db/quran.version';

const uthmaniXml = 'quran-uthmani.xml';
const simpleCleanXml = 'quran-simple-clean.xml';
const metadataXml = 'quran-data.xml';
const qulLayoutDb = 'qul-layout-kfgqpc-v4.db';
const qulScriptDb = 'qul-script-kfgqpc-hafs-wbw.db';
const qulImlaeiDb = 'qul-script-imlaei-simple-wbw.db';

/// Development-only stand-ins for the QUL files, generated from Tanzil by
/// tool/make_dev_sources.dart. Never used for a release (verify_quran.dart --release fails).
const devDir = 'tool/sources/dev';

String sha256Of(String path) => sha256.convert(File(path).readAsBytesSync()).toString();

/// Fails unless every [names] file exists and matches tool/sources.lock.json. A null lock entry
/// prints the computed hash so it can be reviewed and recorded with `--record`.
void checkSources(List<String> names, {bool record = false}) {
  final lock = (jsonDecode(File(lockFile).readAsStringSync()) as Map).cast<String, dynamic>();
  var ok = true;
  for (final name in names) {
    final path = '$sourcesDir/$name';
    if (!File(path).existsSync()) {
      stderr.writeln('Missing $path: see tool/README.md for how to download it.');
      ok = false;
      continue;
    }
    final actual = sha256Of(path);
    final expected = lock[name] as String?;
    if (expected == null) {
      if (record) {
        lock[name] = actual;
        stdout.writeln('Recorded $name $actual');
      } else {
        stderr.writeln('No checksum recorded for $name ($actual). Review the file, then re-run '
            'with --record.');
        ok = false;
      }
    } else if (expected != actual) {
      stderr.writeln('Checksum mismatch for $name: expected $expected, got $actual.');
      ok = false;
    }
  }
  if (record) {
    File(lockFile).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(lock)}\n');
  }
  if (!ok) exit(1);
}

class TanzilSura {
  TanzilSura(this.index, this.ayas, this.name, this.tname, this.type);
  final int index;
  final int ayas;
  final String name;
  final String tname;
  final String type; // Meccan | Medinan
}

class TanzilRef {
  TanzilRef(this.index, this.sura, this.aya);
  final int index;
  final int sura;
  final int aya;
}

class TanzilMetadata {
  TanzilMetadata(this.suras, this.juzs, this.quarters, this.pages, this.sajdas);
  final List<TanzilSura> suras;
  final List<TanzilRef> juzs;
  final List<TanzilRef> quarters;
  final List<TanzilRef> pages;
  final List<TanzilRef> sajdas;

  static TanzilMetadata load(String path) {
    final doc = XmlDocument.parse(File(path).readAsStringSync());
    List<TanzilRef> refs(String tag) => [
          for (final e in doc.findAllElements(tag))
            TanzilRef(int.parse(e.getAttribute('index')!), int.parse(e.getAttribute('sura')!),
                int.parse(e.getAttribute('aya')!)),
        ];
    return TanzilMetadata(
      [
        for (final e in doc.findAllElements('sura'))
          TanzilSura(
            int.parse(e.getAttribute('index')!),
            int.parse(e.getAttribute('ayas')!),
            e.getAttribute('name')!,
            e.getAttribute('tname')!,
            e.getAttribute('type')!,
          ),
      ],
      refs('juz'),
      refs('quarter'),
      refs('page'),
      refs('sajda'),
    );
  }
}

class TanzilAya {
  TanzilAya(this.sura, this.aya, this.text, this.bismillah);
  final int sura;
  final int aya;
  final String text;
  final String? bismillah;
}

/// All 6,236 ayahs of a Tanzil XML text, in Mushaf order.
List<TanzilAya> loadTanzilText(String path) {
  final doc = XmlDocument.parse(File(path).readAsStringSync());
  return [
    for (final sura in doc.findAllElements('sura'))
      for (final aya in sura.findElements('aya'))
        TanzilAya(
          int.parse(sura.getAttribute('index')!),
          int.parse(aya.getAttribute('index')!),
          aya.getAttribute('text')!,
          aya.getAttribute('bismillah'),
        ),
  ];
}

/// True for an ayah-end marker token: Arabic-Indic digits, optionally with U+06DD.
bool isAyahEndToken(String text) =>
    text.isNotEmpty &&
    text.runes.every((c) =>
        (c >= 0x0660 && c <= 0x0669) || (c >= 0x06F0 && c <= 0x06F9) || c == 0x06DD || c == 0x20);

/// True when [token] has no Arabic letter (pause marks, sajdah sign): it belongs to the previous
/// word rather than being a word of its own.
bool isMarkOnly(String token) => !token.runes.any(_isLetter);

bool _isLetter(int c) =>
    (c >= 0x0621 && c <= 0x063A) || (c >= 0x0641 && c <= 0x064A) || c == 0x0671 ||
    (c >= 0x06A9 && c <= 0x06D3);

/// Splits a Tanzil ayah into words, attaching mark-only tokens to the preceding word.
List<String> tanzilWords(String text) {
  final words = <String>[];
  for (final t in text.split(' ').where((t) => t.isNotEmpty)) {
    if (words.isNotEmpty && isMarkOnly(t)) {
      words[words.length - 1] = '${words.last} $t';
    } else {
      words.add(t);
    }
  }
  return words;
}

/// Eastern Arabic digits for ayah-end markers.
String easternDigits(int n) =>
    String.fromCharCodes(n.toString().codeUnits.map((u) => u - 0x30 + 0x0660));

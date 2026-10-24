import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/mp3_frames.dart';

/// The frame reader of the QUL surah clips (specs/006 T010, research R18, R19).
void main() {
  /// One frame: a header (MPEG-1 Layer III, no CRC) and silent payload.
  List<int> frame(int kbps, int rate, {bool padding = false}) {
    const rates = [44100, 48000, 32000];
    const kbpsList = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
    final length = 144000 * kbps ~/ rate + (padding ? 1 : 0);
    return [
      0xFF,
      0xFB,
      kbpsList.indexOf(kbps) << 4 | rates.indexOf(rate) << 2 | (padding ? 2 : 0),
      0x44,
      ...List.filled(length - 4, 0),
    ];
  }

  /// [count] CBR frames at 44.1 kHz with padding where an encoder would put it, so frames are
  /// 417 or 418 bytes at 128 kbps.
  List<int> frames44(int count, {int kbps = 128}) {
    final out = <int>[];
    var remainder = 0.0;
    for (var i = 0; i < count; i++) {
      final exact = 144000 * kbps / 44100;
      remainder += exact - exact.floor();
      final pad = remainder >= 1;
      if (pad) remainder -= 1;
      out.addAll(frame(kbps, 44100, padding: pad));
    }
    return out;
  }

  List<int> id3(int size) => [
        0x49, 0x44, 0x33, 3, 0, 0, //
        (size >> 21) & 0x7f, (size >> 14) & 0x7f, (size >> 7) & 0x7f, size & 0x7f,
        ...List.filled(size, 0),
      ];

  test('id3Length reads the synchsafe size, and 0 without a tag', () {
    expect(id3Length(Uint8List.fromList(id3(200))), 210);
    expect(id3Length(Uint8List.fromList(id3(110491))), 110501);
    expect(id3Length(Uint8List.fromList(frame(128, 44100))), 0);
  });

  test('parseFrameHeader gives bitrate, sample rate and length', () {
    final f = parseFrameHeader(Uint8List.fromList(frame(128, 44100, padding: true)), 0)!;
    expect((f.bitrateKbps, f.sampleRate, f.length), (128, 44100, 418));
    final g = parseFrameHeader(Uint8List.fromList(frame(96, 48000)), 0)!;
    expect((g.bitrateKbps, g.sampleRate, g.length), (96, 48000, 288));
    expect(parseFrameHeader(Uint8List.fromList([0xFF, 0xFB, 0xF0, 0x44]), 0), isNull,
        reason: 'bitrate index 15 is invalid');
  });

  test('checkCbr accepts constant bitrate and rejects mixed bitrates and Xing', () {
    final head = Uint8List.fromList([...id3(100), ...frames44(50)]);
    final cbr = checkCbr(head, id3Length(head));
    expect((cbr.bitrateKbps, cbr.sampleRate, cbr.audioStart), (128, 44100, 110));

    final mixed = Uint8List.fromList([...frames44(10), ...frame(96, 44100), ...frames44(40)]);
    expect(() => checkCbr(mixed, 0), throwsFormatException);

    final xing = frame(128, 44100);
    xing.setRange(36, 40, 'Xing'.codeUnits);
    expect(() => checkCbr(Uint8List.fromList([...xing, ...frames44(40)]), 0), throwsFormatException);

    final info = frame(128, 44100);
    info.setRange(36, 40, 'Info'.codeUnits);
    expect(checkCbr(Uint8List.fromList([...info, ...frames44(40)]), 0).bitrateKbps, 128);
  });

  test('frameStartAtOrAfter finds the frame grid at 44.1 kHz with padding', () {
    final bytes = Uint8List.fromList(frames44(200));
    final starts = <int>[];
    for (var i = 0; i < bytes.length;) {
      starts.add(i);
      i += parseFrameHeader(bytes, i)!.length;
    }
    const cbr = CbrInfo(128, 44100, 0);
    for (final target in [0, 1, 417, 418, 5000, 41795, 60000]) {
      final expected = starts.firstWhere((s) => s >= target);
      final windowStart = (target - 500).clamp(0, bytes.length);
      final window = bytes.sublist(windowStart, (windowStart + 4096).clamp(0, bytes.length));
      expect(frameStartAtOrAfter(window, windowStart, target, cbr), expected, reason: '$target');
    }
  });

  test('frameStartAtOrAfter skips a stray sync pattern in audio data', () {
    final bytes = frames44(20);
    bytes.setRange(100, 104, [0xFF, 0xFB, 0x90, 0x44]); // looks like a header, inside frame 0
    const cbr = CbrInfo(128, 44100, 0);
    expect(frameStartAtOrAfter(Uint8List.fromList(bytes), 0, 50, cbr), 417);
  });

  test('MPEG-2 Layer III (24 kHz) frames, and padding after the ID3 tag', () {
    // 0xFF 0xF3: MPEG-2 Layer III; 0xD4: 144 kbps, 24 kHz (as Khalid Al-Jalil's Al-Fatiha).
    final f = [0xFF, 0xF3, 0xD4, 0x64, ...List.filled(72 * 144000 ~/ 24000 - 4, 0)];
    final g = parseFrameHeader(Uint8List.fromList(f), 0)!;
    expect((g.bitrateKbps, g.sampleRate, g.samplesPerFrame, g.length), (144, 24000, 576, 432));
    final head = Uint8List.fromList([...id3(20), 0, 0, 0, for (var i = 0; i < 50; i++) ...f]);
    final cbr = checkCbr(head, id3Length(head));
    expect((cbr.audioStart, cbr.frameMs), (33, 24.0));
  });

  test('frameStartAtOrAfter at 48 kHz, where frames have no padding', () {
    final bytes = Uint8List.fromList([for (var i = 0; i < 100; i++) ...frame(96, 48000)]);
    const cbr = CbrInfo(96, 48000, 0);
    expect(frameStartAtOrAfter(bytes, 0, 289, cbr), 576);
    expect(cbr.predictOffset(24.0 * 10), 2880);
  });
}

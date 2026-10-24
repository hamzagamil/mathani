// MPEG-1 Layer III frame reading for QUL surah recordings played as ayah clips
// (specs/006-reciters-memorization research R18, R19). Pure Dart, no Flutter, so the build tool
// and the unit tests share it.
import 'dart:typed_data';

/// Bytes read from the start of a surah file: the ID3 tag and enough frames for [checkCbr].
const headerProbeBytes = 131072;

/// Bytes read around each predicted ayah boundary to find the exact frame start.
const frameProbeBytes = 4096;

/// Frames checked for a constant bitrate.
const cbrCheckFrames = 40;

// Layer III tables. MPEG-2 and 2.5 (lower sample rates) share one bitrate table; some surah
// files use them (for example Khalid Al-Jalil's Al-Fatiha, 24 kHz), others in the same recitation
// MPEG-1.
const _bitratesMpeg1 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
const _bitratesMpeg2 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];
const _sampleRatesMpeg1 = [44100, 48000, 32000];
const _sampleRatesMpeg2 = [22050, 24000, 16000];
const _sampleRatesMpeg25 = [11025, 12000, 8000];

/// Length of an ID3v2 tag at the start of [head] (10-byte header plus its synchsafe size, plus
/// the footer when present), or 0 when there is none.
int id3Length(Uint8List head) {
  if (head.length < 10 || head[0] != 0x49 || head[1] != 0x44 || head[2] != 0x33) return 0;
  final size = (head[6] & 0x7f) << 21 | (head[7] & 0x7f) << 14 | (head[8] & 0x7f) << 7 | head[9] & 0x7f;
  final footer = head[5] & 0x10 != 0 ? 10 : 0;
  return 10 + size + footer;
}

class FrameInfo {
  const FrameInfo(this.bitrateKbps, this.sampleRate, this.padding);

  final int bitrateKbps;
  final int sampleRate;
  final bool padding;

  /// MPEG-1 frames hold 1152 samples; MPEG-2 and 2.5 Layer III frames 576.
  int get samplesPerFrame => sampleRate >= 32000 ? 1152 : 576;

  /// Frame length in bytes: samples / 8 × kbps × 1000 / sample rate, plus the padding byte.
  int get length => samplesPerFrame * 125 * bitrateKbps ~/ sampleRate + (padding ? 1 : 0);
}

/// The Layer III frame header (MPEG-1, 2 or 2.5) at [i] in [b], or null when there is none.
FrameInfo? parseFrameHeader(Uint8List b, int i) {
  if (i < 0 || i + 4 > b.length) return null;
  if (b[i] != 0xFF || b[i + 1] & 0xE0 != 0xE0) return null;
  final version = (b[i + 1] >> 3) & 3; // 3: MPEG-1, 2: MPEG-2, 0: MPEG-2.5, 1: reserved
  if (version == 1) return null;
  if ((b[i + 1] >> 1) & 3 != 1) return null; // Layer III
  final bitrateIndex = b[i + 2] >> 4;
  final rateIndex = (b[i + 2] >> 2) & 3;
  if (bitrateIndex == 0 || bitrateIndex == 15 || rateIndex == 3) return null;
  final bitrates = version == 3 ? _bitratesMpeg1 : _bitratesMpeg2;
  final rates = switch (version) {
    3 => _sampleRatesMpeg1,
    2 => _sampleRatesMpeg2,
    _ => _sampleRatesMpeg25,
  };
  return FrameInfo(bitrates[bitrateIndex], rates[rateIndex], (b[i + 2] >> 1) & 1 == 1);
}

/// A constant-bitrate file: its bitrate, sample rate and the offset of its first frame.
class CbrInfo {
  const CbrInfo(this.bitrateKbps, this.sampleRate, this.audioStart);

  final int bitrateKbps;
  final int sampleRate;
  final int audioStart;

  int get samplesPerFrame => sampleRate >= 32000 ? 1152 : 576;

  /// Duration of one frame.
  double get frameMs => samplesPerFrame * 1000 / sampleRate;

  /// Average frame length, used to predict an offset from a time.
  double get averageFrameBytes => samplesPerFrame * 125 * bitrateKbps / sampleRate;

  /// The predicted byte offset of [ms]: a whole number of frames after [audioStart].
  int predictOffset(double ms) =>
      audioStart + ((ms / frameMs).floor() * averageFrameBytes).floor();

  bool matches(FrameInfo f) => f.bitrateKbps == bitrateKbps && f.sampleRate == sampleRate;
}

/// Checks that [head] (the first bytes of a file) holds [cbrCheckFrames] consecutive frames with
/// one bitrate and sample rate, and no VBR header, starting at the first frame at or after [from]
/// (the end of the ID3 tag; some files have padding after it). A LAME `Info` header marks a CBR
/// file and is accepted. Throws [FormatException] otherwise.
CbrInfo checkCbr(Uint8List head, int from) {
  final audioStart = _firstFrame(head, from);
  if (audioStart == null) throw FormatException('No Layer III frame after $from');
  final first = parseFrameHeader(head, audioStart)!;
  final tag = String.fromCharCodes(
      head.sublist(audioStart, (audioStart + first.length).clamp(0, head.length)));
  if (tag.contains('Xing') || tag.contains('VBRI')) {
    throw const FormatException('Variable bitrate (Xing/VBRI header)');
  }
  final cbr = CbrInfo(first.bitrateKbps, first.sampleRate, audioStart);
  var i = audioStart;
  for (var n = 0; n < cbrCheckFrames; n++) {
    final f = parseFrameHeader(head, i);
    if (f == null) {
      if (i + 4 > head.length) break; // probe ended: the frames read so far agree
      throw FormatException('Frame $n at $i is not a valid frame');
    }
    if (!cbr.matches(f)) {
      throw FormatException('Frame $n is ${f.bitrateKbps} kbps at ${f.sampleRate} Hz, '
          'not ${cbr.bitrateKbps} kbps at ${cbr.sampleRate} Hz');
    }
    i += f.length;
  }
  return cbr;
}

/// The first offset at or after [from] where three consecutive frames of one bitrate and sample
/// rate begin, or null.
int? _firstFrame(Uint8List b, int from) {
  for (var i = from; i + 4 <= b.length; i++) {
    final f = parseFrameHeader(b, i);
    if (f == null) continue;
    final next = parseFrameHeader(b, i + f.length);
    final after = next == null ? null : parseFrameHeader(b, i + f.length + next.length);
    bool same(FrameInfo? g) =>
        g != null && g.bitrateKbps == f.bitrateKbps && g.sampleRate == f.sampleRate;
    if (same(next) && same(after)) return i;
  }
  return null;
}

/// The offset in the file of the first frame starting at or after [target], searching [window]
/// (bytes of the file from [windowOffset]). A frame counts only when it and the next two frames
/// have [cbr]'s bitrate and sample rate, so a stray sync pattern in audio data is skipped. Throws
/// [StateError] when the window holds no such frame.
int frameStartAtOrAfter(Uint8List window, int windowOffset, int target, CbrInfo cbr) {
  for (var i = (target - windowOffset).clamp(0, window.length); i + 4 <= window.length; i++) {
    var j = i;
    var chained = 0;
    while (chained < 3) {
      final f = parseFrameHeader(window, j);
      if (f == null || !cbr.matches(f)) break;
      chained++;
      j += f.length;
      if (j + 4 > window.length) {
        chained = 3; // the chain runs past the window: accept what was read
      }
    }
    if (chained == 3) return windowOffset + i;
  }
  throw StateError('No frame at or after $target in $windowOffset..'
      '${windowOffset + window.length}');
}

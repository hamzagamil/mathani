// A memorization session (specs/006 contracts/memorization-engine.md › MemorizationController):
// the reader recites a range from memory, each ayah is revealed once recited, and the session
// ends with a score. The voice stays on the device (FR-019).
import 'dart:async';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../data/models.dart';
import '../../shared/device_channel.dart';
import '../../shared/reader_state.dart';
import '../recitation/recitation_controller.dart';
import '../search/arabic_normalizer.dart';
import 'asr_model.dart';
import 'device_support.dart';
import 'memorization_score.dart';
import 'mic_source.dart';
import 'recitation_matcher.dart';
import 'speech_recogniser.dart';

/// Listening stops after this long without a segment (R14).
const silencePause = Duration(seconds: 30);

/// On End, the last segment is still matched if it arrives within this.
const endFlushWait = Duration(milliseconds: 1500);

/// The mistake tone, during which the microphone is gated (R12).
const toneLength = Duration(milliseconds: 120);

enum MemorizationPhase { preparing, listening, paused, ended }

enum PauseReason { user, silence, interruption, background, routeLost }

enum StartOutcome { started, unsupportedDevice, needsModel, micDenied, micPermanentlyDenied }

/// Ayat [from]..[to] of one surah (FR-009).
@immutable
class MemorizationRange {
  const MemorizationRange(this.surah, this.from, this.to) : assert(from <= to);
  final int surah;
  final int from;
  final int to;

  int get length => to - from + 1;
  AyahRef refAt(int index) => AyahRef(surah, from + index);
  bool contains(AyahRef ref) => ref.surah == surah && ref.ayah >= from && ref.ayah <= to;

  @override
  bool operator ==(Object other) =>
      other is MemorizationRange && other.surah == surah && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(surah, from, to);
}

class MemorizationController extends ChangeNotifier with WidgetsBindingObserver {
  MemorizationController({
    required this.reader,
    this.recitation,
    AsrModel? model,
    SpeechRecogniser Function()? recogniser,
    MicSource Function()? mic,
    this.device = const DeviceChannel(),
  })  : model = model ?? AsrModel(device: device),
        _newRecogniser = recogniser ?? SherpaSpeechRecogniser.new,
        _newMic = mic ?? MicSource.new;

  final ReaderController reader;
  final RecitationController? recitation;
  final AsrModel model;
  final DeviceChannel device;
  final SpeechRecogniser Function() _newRecogniser;
  final MicSource Function() _newMic;

  SpeechRecogniser? _recogniser;
  MicSource? _mic;
  StreamSubscription<Segment>? _segments;
  StreamSubscription<Float32List>? _samples;
  Timer? _silence;
  StreamSubscription<AudioInterruptionEvent>? _interruptions;
  StreamSubscription<void>? _noisy;
  bool _observing = false;

  MemorizationPhase? _phase;

  /// Null while no session exists.
  MemorizationPhase? get phase => _phase;
  bool get active => _phase != null && _phase != MemorizationPhase.ended;

  PauseReason? _pauseReason;
  PauseReason? get pauseReason => _pauseReason;

  MemorizationRange? _range;
  MemorizationRange? get range => _range;

  RecitationMatcher? _matcher;
  final _rangeWords = <int>{}; // word ids of the range, hidden until revealed
  final _hintedWords = <int>{};
  final _revealedWords = <int>{};
  final _mistakeAyat = <AyahRef>{};
  List<List<RefWord>> _ayatWords = const [];

  /// Changes whenever a mark on the page changes, so renderers repaint only then.
  int _revision = 0;
  int get revision => _revision;

  /// Set when a mistake was just heard, for the bar's mistake line.
  int _mistakeSerial = 0;
  int get mistakeSerial => _mistakeSerial;

  /// The latest revealed ayah, for the screen-reader announcement.
  AyahRef? _lastRevealed;
  AyahRef? get lastRevealed => _lastRevealed;

  SessionResult? _result;

  /// Set when the session ends.
  SessionResult? get result => _result;

  /// The ayah the reader is expected to recite; null when done.
  AyahRef? get expected {
    final m = _matcher, r = _range;
    if (m == null || r == null || m.done) return null;
    return r.refAt(m.ayahIndex);
  }

  /// 1-based position of [expected] in the range, for «الآية ٣ من ٧».
  int get expectedNumber => (_matcher?.ayahIndex ?? 0) + 1;

  bool isHidden(int wordId) =>
      active && _rangeWords.contains(wordId) && !_revealedWords.contains(wordId) &&
      !_hintedWords.contains(wordId);

  bool isHinted(int wordId) => active && _hintedWords.contains(wordId);

  bool hasMistake(AyahRef ref) => active && _mistakeAyat.contains(ref);

  /// Whether [ref]'s words are still hidden (for semantics and the ayah actions).
  bool isAyahHidden(AyahRef ref) {
    final r = _range, m = _matcher;
    if (!active || r == null || m == null || !r.contains(ref)) return false;
    return !m.tallies[ref.ayah - r.from].complete;
  }

  /// Gate, model, microphone, then listening (contract › Start sequence).
  /// [explain] shows the microphone explainer and returns whether to continue; it is called only
  /// when the system has not been asked yet.
  Future<StartOutcome> start(MemorizationRange range,
      {Future<bool> Function()? explain, bool micAskedBefore = false}) async {
    await recitation?.stop();
    if (await memorizationSupport(device) != null) return StartOutcome.unsupportedDevice;
    await model.refresh();
    if (model.state != AsrModelState.ready) return StartOutcome.needsModel;
    final mic = _mic ??= _newMic();
    if (!await mic.hasPermission()) {
      if (micAskedBefore) return StartOutcome.micPermanentlyDenied;
      if (explain != null && !await explain()) return StartOutcome.micDenied;
      if (!await mic.requestPermission()) return StartOutcome.micDenied;
    }

    _reset();
    _range = range;
    _phase = MemorizationPhase.preparing;
    notifyListeners();

    final words = await reader.quran.memorizationWords(range.surah, range.from, range.to);
    _ayatWords = [
      for (final ayat in words) [for (final w in ayat) RefWord(w.wordId, w.position, w.form)],
    ];
    _rangeWords.addAll([for (final ayat in _ayatWords) for (final w in ayat) w.wordId]);
    _matcher = RecitationMatcher(_ayatWords);
    _bump();
    reader.jumpTo(range.refAt(0), highlight: false);

    final recogniser = _recogniser ??= _newRecogniser();
    await recogniser.load(model.modelDir);
    _segments = recogniser.segments.listen(_onSegment);
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
      // A call or other audio, or the headset unplugged, pauses listening (R14).
      try {
        final session = await AudioSession.instance;
        _interruptions = session.interruptionEventStream.listen((e) {
          if (e.begin) pause(PauseReason.interruption);
        });
        _noisy = session.becomingNoisyEventStream.listen((_) => pause(PauseReason.routeLost));
      } on MissingPluginException {
        // No audio session (tests): nothing interrupts.
      }
    }
    await _listen();
    return StartOutcome.started;
  }

  Future<void> _listen() async {
    final mic = _mic!;
    _samples ??= mic.samples.listen((s) => _recogniser?.accept(s));
    await mic.start();
    _phase = MemorizationPhase.listening;
    _pauseReason = null;
    _armSilence();
    notifyListeners();
  }

  void _armSilence() {
    _silence?.cancel();
    _silence = Timer(silencePause, () => pause(PauseReason.silence));
  }

  void _onSegment(Segment segment) {
    final m = _matcher;
    if (m == null || !active) return;
    if (_phase == MemorizationPhase.listening) _armSilence();
    final tokens = normalizeArabic(segment.text).split(' ').where((t) => t.isNotEmpty).toList();
    _apply(m.accept(tokens, finalSegment: !segment.forcedSplit));
  }

  void _apply(MatchEvents e) {
    final r = _range!, m = _matcher!;
    var changed = false;
    if (e.mistakes.isNotEmpty) {
      _mistakeAyat.add(r.refAt(m.done ? m.ayat.length - 1 : m.ayahIndex));
      _mistakeSerial++;
      changed = true;
      _signal();
    }
    for (final ayah in e.completed) {
      _lastRevealed = r.refAt(ayah);
    }
    if (_syncWords() || changed) _bump();
    if (e.ayahCompleted) {
      if (m.done) {
        unawaited(end());
        return;
      }
      // Follow the reader to the next ayah's page (FR-018).
      final next = r.refAt(m.ayahIndex);
      if (reader.quran.pageOf(next) != reader.page) reader.jumpTo(next, highlight: false);
    }
    notifyListeners();
  }

  /// Reveals each word as soon as it is recited, so the first hidden word of the expected ayah is
  /// the one to say (again); hinted words keep the hint colour. Words once shown stay shown, also
  /// when the reader goes back to repeat. True when something changed.
  bool _syncWords() {
    final m = _matcher!;
    final revealed = _revealedWords.length, hinted = _hintedWords.length;
    for (var a = 0; a < m.ayat.length; a++) {
      final tally = m.tallies[a];
      final parts = m.ayat[a];
      final recited = tally.complete ? parts.length : (a == m.ayahIndex ? m.cursor - 1 : 0);
      for (var k = 0; k < recited; k++) {
        final w = parts[k];
        (tally.hints.contains(w.position) ? _hintedWords : _revealedWords).add(w.wordId);
      }
    }
    return _revealedWords.length != revealed || _hintedWords.length != hinted;
  }

  void _signal() {
    switch (reader.preferences.mistakeSignal) {
      case MistakeSignal.vibrate:
        unawaited(HapticFeedback.vibrate());
      case MistakeSignal.sound:
        _mic?.gate(toneLength);
        unawaited(device.playMistakeTone());
      case MistakeSignal.none:
        break;
    }
  }

  /// «الكلمة التالية»: shows the next word in the hint colour (worth 0.25, Q3).
  void nextWord() {
    final m = _matcher;
    if (m == null || !active || m.done) return;
    _apply(m.hintNextWord());
  }

  /// «أظهر الآية»: reveals the expected ayah (worth 0).
  void showAyah() {
    final m = _matcher;
    if (m == null || !active || m.done) return;
    _recogniser?.reset();
    _apply(m.revealRest());
  }

  /// Stops listening at once; the matcher keeps its state (FR-020).
  void pause([PauseReason reason = PauseReason.user]) {
    if (_phase != MemorizationPhase.listening) return;
    _silence?.cancel();
    _phase = MemorizationPhase.paused;
    _pauseReason = reason;
    notifyListeners();
    unawaited(_mic?.stop());
    _recogniser?.flush();
  }

  Future<void> resume() async {
    if (_phase != MemorizationPhase.paused) return;
    _recogniser?.reset();
    await _listen();
  }

  /// Ends the session and builds the result (contract › end()). The ayah being recited counts as
  /// not reached (FR-024).
  Future<void> end() async {
    if (!active) return;
    _silence?.cancel();
    final wasListening = _phase == MemorizationPhase.listening;
    _phase = MemorizationPhase.ended;
    notifyListeners();
    await _mic?.stop();
    if (wasListening) {
      _recogniser?.flush();
      await Future<void>.delayed(endFlushWait);
    }
    await _segments?.cancel();
    _segments = null;
    final m = _matcher;
    _result = m == null ? null : SessionResult.fromTallies(m.tallies);
    _bump();
    notifyListeners();
  }

  /// Clears the ended session (Done on the result screen): the page shows the text again.
  void close() {
    _reset();
    notifyListeners();
  }

  void _reset() {
    _silence?.cancel();
    unawaited(_segments?.cancel());
    _segments = null;
    _phase = null;
    _pauseReason = null;
    _range = null;
    _matcher = null;
    _result = null;
    _lastRevealed = null;
    _rangeWords.clear();
    _hintedWords.clear();
    _revealedWords.clear();
    _mistakeAyat.clear();
    _ayatWords = const [];
    _bump();
  }

  void _bump() => _revision++;

  /// Listening stops when the app leaves the foreground (R14).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      pause(PauseReason.background);
    }
  }

  @override
  void dispose() {
    _silence?.cancel();
    unawaited(_segments?.cancel());
    unawaited(_samples?.cancel());
    unawaited(_interruptions?.cancel());
    unawaited(_noisy?.cancel());
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    unawaited(_mic?.dispose());
    unawaited(_recogniser?.dispose());
    model.dispose();
    super.dispose();
  }
}

/// Gives the reading screen the session (contract › Scope).
class MemorizationScope extends InheritedNotifier<MemorizationController> {
  const MemorizationScope({super.key, required MemorizationController controller, required super.child})
      : super(notifier: controller);

  static MemorizationController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MemorizationScope>()?.notifier;

  /// Without depending on it, for callbacks.
  static MemorizationController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MemorizationScope>()?.notifier;
}

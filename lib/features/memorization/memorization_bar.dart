// The bar of a memorization session (specs/006 contracts/memorization-ui.md › Memorization bar):
// docked like the recitation bar, so it never covers the text.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';
import 'memorization_controller.dart';

/// How long «خطأ — تابع من الكلمة» stays after a mistake.
const mistakeLineDuration = Duration(seconds: 3);

class MemorizationBar extends StatefulWidget {
  const MemorizationBar({super.key, required this.controller});
  final MemorizationController controller;

  @override
  State<MemorizationBar> createState() => _MemorizationBarState();
}

class _MemorizationBarState extends State<MemorizationBar> {
  late int _seenMistakes = widget.controller.mistakeSerial;
  Timer? _mistakeLine;

  @override
  void dispose() {
    _mistakeLine?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.controller;
    final reader = ReaderScope.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final locale = Localizations.localeOf(context);
    final range = m.range;
    if (range == null) return const SizedBox.shrink();

    if (m.mistakeSerial != _seenMistakes) {
      _seenMistakes = m.mistakeSerial;
      _mistakeLine?.cancel();
      _mistakeLine = Timer(mistakeLineDuration, () {
        if (mounted) setState(() => _mistakeLine = null);
      });
    }
    final showMistake = _mistakeLine?.isActive ?? false;

    final listening = m.phase == MemorizationPhase.listening;
    final paused = m.phase == MemorizationPhase.paused;
    final preparing = m.phase == MemorizationPhase.preparing;
    final status = preparing
        ? l10n.memorizePreparing
        : listening
            ? l10n.memorizeListening
            : switch (m.pauseReason) {
                PauseReason.silence => l10n.memorizePausedSilence,
                PauseReason.interruption => l10n.memorizePausedInterruption,
                PauseReason.background => l10n.memorizePausedBackground,
                PauseReason.routeLost => l10n.memorizePausedRoute,
                _ => l10n.memorizePaused,
              };
    final expected = m.expected;
    final away = expected != null && reader.quran.pageOf(expected) != reader.page;
    final number = expected == null ? range.length : m.expectedNumber;

    final indicator = Semantics(
      label: listening ? l10n.memorizeMicOn : null,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: listening ? const Color(0xFFD32F2F) : colors.inkMuted,
          ),
        ),
        const SizedBox(width: Space.s2),
        Flexible(
          child: Text(status,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TypeScale.caption.copyWith(fontFamily: TypeScale.uiFamily, color: colors.ink)),
        ),
      ]),
    );

    final controls = IconTheme(
      data: IconThemeData(color: colors.ink),
      child: Row(children: [
        IconButton(
          icon: Icon(listening ? MathaniIcons.pause : MathaniIcons.mic),
          tooltip: listening ? l10n.memorizePause : l10n.memorizeResume,
          onPressed: preparing ? null : (listening ? m.pause : m.resume),
        ),
        IconButton(
          icon: const Icon(MathaniIcons.hint),
          tooltip: l10n.memorizeNextWord,
          onPressed: preparing || expected == null ? null : m.nextWord,
        ),
        IconButton(
          icon: const Icon(MathaniIcons.reveal),
          tooltip: l10n.memorizeShowAyah,
          onPressed: preparing || expected == null ? null : m.showAyah,
        ),
        const Spacer(),
        TextButton.icon(
          icon: const Icon(MathaniIcons.endSession),
          label: Text(l10n.memorizeEnd),
          onPressed: m.end,
        ),
      ]),
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.memorize,
      child: Material(
        color: colors.surfaceRaised,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.line))),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s2),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  height: 44,
                  child: Row(children: [
                    Expanded(child: indicator),
                    Text(
                      l10n.memorizeProgress(formatNumber(number, locale), formatNumber(range.length, locale)),
                      style: TypeScale.titleSm.copyWith(fontFamily: TypeScale.uiFamily, color: colors.ink),
                    ),
                    if (paused || away) const SizedBox(width: Space.s2),
                  ]),
                ),
                if (showMistake || away)
                  Row(children: [
                    if (showMistake)
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(l10n.memorizeMistake,
                              style: TypeScale.body.copyWith(fontFamily: TypeScale.uiFamily, color: colors.mistake)),
                        ),
                      )
                    else
                      const Spacer(),
                    if (away)
                      TextButton.icon(
                        icon: const Icon(MathaniIcons.locate, size: 18),
                        label: Text(l10n.memorizeBackToAyah),
                        onPressed: () => reader.jumpTo(expected, highlight: false),
                      ),
                  ]),
                controls,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

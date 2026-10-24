// A miniature reading screen that shows a gesture (specs/005-app-onboarding/research.md › R3).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../data/models.dart';
import '../../shared/mathani_icons.dart';
import 'onboarding_steps.dart';

/// One loop of a gesture animation.
const gestureLoop = Duration(milliseconds: 2400);

/// The reading screen drawn small, in the reader's layout and theme. Without [gesture] it is a
/// still preview (theme and layout steps); with one of the gesture stops it animates that gesture
/// with a touch dot, or shows a still frame with an arrow when animations are off. Hidden from
/// screen readers: the stop's text says the gesture (Story 3 AS3).
class TourIllustration extends StatefulWidget {
  const TourIllustration({super.key, required this.layout, this.gesture});

  final ReadingLayout layout;

  /// [OnboardingStep.turnPages], [OnboardingStep.controls] or [OnboardingStep.ayahActions].
  final OnboardingStep? gesture;

  @override
  State<TourIllustration> createState() => _TourIllustrationState();
}

class _TourIllustrationState extends State<TourIllustration> with SingleTickerProviderStateMixin {
  AnimationController? _loop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(TourIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final animate = widget.gesture != null && !MediaQuery.disableAnimationsOf(context);
    if (animate && _loop == null) {
      _loop = AnimationController(vsync: this, duration: gestureLoop)..repeat();
    } else if (!animate && _loop != null) {
      _loop!.dispose();
      _loop = null;
    }
  }

  @override
  void dispose() {
    _loop?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = math.min(240.0, MediaQuery.sizeOf(context).height * 0.32);
    return ExcludeSemantics(
      child: Center(
        child: RepaintBoundary(
          child: SizedBox(
            height: height,
            width: height * 0.62,
            child: CustomPaint(
              painter: _MiniScreenPainter(
                layout: widget.layout,
                gesture: widget.gesture,
                loop: _loop,
                colors: MathaniColors.of(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniScreenPainter extends CustomPainter {
  _MiniScreenPainter({required this.layout, this.gesture, this.loop, required this.colors})
      : super(repaint: loop);

  final ReadingLayout layout;
  final OnboardingStep? gesture;

  /// Null: a still frame.
  final Animation<double>? loop;
  final MathaniColors colors;

  static const _lines = 15;
  static const _dotRadius = 12.0;

  bool get _mushaf => layout == ReadingLayout.mushaf;

  /// Where in the loop the frame is; a still frame shows the gesture's telling moment.
  double get _t =>
      loop?.value ??
      switch (gesture) {
        OnboardingStep.turnPages => 0.3,
        OnboardingStep.controls => 0.4,
        OnboardingStep.ayahActions => 0.7,
        _ => 0,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final screen = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    canvas.drawRRect(screen, Paint()..color = colors.surface);
    canvas.save();
    canvas.clipRRect(screen);
    switch (gesture) {
      case OnboardingStep.turnPages:
        _turnPages(canvas, size);
      case OnboardingStep.controls:
        _controls(canvas, size);
      case OnboardingStep.ayahActions:
        _ayahActions(canvas, size);
      default:
        _content(canvas, size, Offset.zero);
        if (!_mushaf) _bars(canvas, size, 1);
    }
    canvas.restore();
    canvas.drawRRect(
        screen,
        Paint()
          ..color = colors.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  // --- Content ---------------------------------------------------------------------------------

  /// The text area: in the Mushaf layout a sheet of paper, in the flowing layout ragged lines.
  Rect _area(Size size) => _mushaf
      ? Rect.fromLTRB(size.width * 0.08, size.height * 0.06, size.width * 0.92, size.height * 0.94)
      : Rect.fromLTRB(size.width * 0.08, size.height * 0.13, size.width * 0.92, size.height * 0.87);

  double _lineStep(Size size) => _area(size).height / (_lines + 1);

  Rect _lineRect(Size size, int line, {double scroll = 0}) {
    final area = _area(size);
    final step = _lineStep(size);
    final y = area.top + step * (line + 0.6) - scroll;
    final inset = _mushaf ? area.width * 0.08 : 0.0;
    var left = area.left + inset;
    if (!_mushaf) {
      // Ragged right-to-left lines: each ends at a different place on the left.
      const shorten = [0.0, 0.1, 0.0, 0.25, 0.05, 0.0, 0.15, 0.4, 0.0, 0.08, 0.0, 0.2, 0.05, 0.3];
      left += area.width * shorten[line % shorten.length];
    }
    return Rect.fromLTRB(left, y, area.right - inset, y + step * 0.32);
  }

  void _content(Canvas canvas, Size size, Offset offset, {double scroll = 0, int? selected}) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    final area = _area(size);
    if (_mushaf) {
      final sheet = RRect.fromRectAndRadius(area, const Radius.circular(4));
      canvas.drawRRect(sheet, Paint()..color = colors.surfaceRaised);
      canvas.drawRRect(
          sheet,
          Paint()
            ..color = colors.line
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }
    canvas.save();
    canvas.clipRect(area);
    final ink = Paint()..color = colors.ink.withValues(alpha: 0.35);
    final marker = Paint()..color = colors.accent;
    final step = _lineStep(size);
    final first = (scroll / step).floor();
    for (var i = first; i < first + _lines + 2; i++) {
      final line = _lineRect(size, i, scroll: scroll);
      if (i == selected) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(line.inflate(step * 0.22), const Radius.circular(3)),
            Paint()..color = colors.selected);
      }
      canvas.drawRRect(
          RRect.fromRectAndRadius(line, Radius.circular(line.height / 2)), ink);
      if (!_mushaf && i % 3 == 1) {
        canvas.drawCircle(Offset(line.left - step * 0.3, line.center.dy), step * 0.18, marker);
      }
    }
    canvas.restore();
    canvas.restore();
  }

  /// Header and toolbar, slid in by [shown] (0 hidden, 1 shown).
  void _bars(Canvas canvas, Size size, double shown) {
    if (shown <= 0) return;
    final h = size.height * 0.09;
    final bar = Paint()..color = colors.bar;
    canvas.drawRect(Rect.fromLTWH(0, -h + h * shown, size.width, h), bar);
    final bottom = Rect.fromLTWH(0, size.height - h * shown, size.width, h);
    canvas.drawRect(bottom, Paint()..color = colors.surfaceRaised);
    canvas.drawLine(bottom.topLeft, bottom.topRight, Paint()..color = colors.line);
    final dot = Paint()..color = colors.ink.withValues(alpha: 0.6);
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
          Offset(size.width * (i + 1) / 6, bottom.center.dy), size.width * 0.025, dot);
    }
  }

  // --- Gestures --------------------------------------------------------------------------------

  /// Drag towards the right: the next sheet comes in from the left, as the right-to-left PageView
  /// in mushaf_view.dart turns pages. In the flowing layout, drag up and the text scrolls.
  void _turnPages(Canvas canvas, Size size) {
    final p = Curves.easeInOut.transform(_segment(_t, 0.15, 0.6));
    if (_mushaf) {
      final shift = size.width * p;
      _content(canvas, size, Offset(shift, 0));
      _content(canvas, size, Offset(shift - size.width, 0));
      final from = Offset(size.width * 0.3, size.height * 0.5);
      final to = Offset(size.width * 0.8, size.height * 0.5);
      _dragDot(canvas, from, to, p);
    } else {
      final scroll = _lineStep(size) * 4 * p;
      _content(canvas, size, Offset.zero, scroll: scroll);
      _bars(canvas, size, 1);
      final from = Offset(size.width * 0.5, size.height * 0.7);
      final to = Offset(size.width * 0.5, size.height * 0.35);
      _dragDot(canvas, from, to, p);
    }
  }

  /// Tap to show the controls, tap again to hide them. The flowing layout keeps them.
  void _controls(Canvas canvas, Size size) {
    final t = _t;
    final shown = _mushaf
        ? (t < 0.6 ? _segment(t, 0.1, 0.25) : 1 - _segment(t, 0.6, 0.75))
        : 1.0;
    _content(canvas, size, Offset.zero);
    _bars(canvas, size, Curves.easeOut.transform(shown));
    final center = Offset(size.width * 0.5, size.height * 0.5);
    if (loop == null) {
      _dot(canvas, center, ring: 0.5);
      return;
    }
    for (final start in const [0.05, 0.55]) {
      final p = _segment(t, start, start + 0.2);
      if (p > 0 && p < 1) _dot(canvas, center, ring: p);
    }
  }

  /// Press and hold an ayah: it is selected and the actions rise from the bottom.
  void _ayahActions(Canvas canvas, Size size) {
    final t = _t;
    const line = 6;
    final selected = t >= 0.35 && t < 0.95;
    _content(canvas, size, Offset.zero, selected: selected ? line : null);
    if (!_mushaf) _bars(canvas, size, 1);
    final at = _lineRect(size, line).center;
    if (t >= 0.1 && t < 0.95) _dot(canvas, at, ring: _segment(t, 0.1, 0.35));
    final rise = Curves.easeOut.transform(_segment(t, 0.4, 0.55));
    if (rise > 0 && t < 0.95) _sheet(canvas, size, rise);
  }

  void _sheet(Canvas canvas, Size size, double rise) {
    final h = size.height * 0.2;
    final rect = Rect.fromLTWH(0, size.height - h * rise, size.width, h);
    canvas.drawRRect(
        RRect.fromRectAndCorners(rect,
            topLeft: const Radius.circular(10), topRight: const Radius.circular(10)),
        Paint()..color = colors.surfaceRaised);
    canvas.drawLine(rect.topLeft, rect.topRight, Paint()..color = colors.line);
    const icons = [
      MathaniIcons.play,
      MathaniIcons.bookmark,
      MathaniIcons.copy,
      MathaniIcons.share,
    ];
    for (var i = 0; i < icons.length; i++) {
      final icon = icons[i];
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
              fontFamily: icon.fontFamily, fontSize: size.width * 0.11, color: colors.ink),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final center = Offset(size.width * (i + 1) / (icons.length + 1), rect.top + h * 0.45);
      painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
      painter.dispose();
    }
  }

  /// A drag from [from] to [to] at progress [p]; a still frame draws the path as an arrow.
  void _dragDot(Canvas canvas, Offset from, Offset to, double p) {
    if (loop == null) {
      _arrow(canvas, from, to);
      _dot(canvas, from);
      return;
    }
    if (_t < 0.1 || _t > 0.7) return;
    _dot(canvas, Offset.lerp(from, to, p)!);
  }

  void _dot(Canvas canvas, Offset at, {double? ring}) {
    canvas.drawCircle(at, _dotRadius, Paint()..color = colors.accent.withValues(alpha: 0.7));
    if (ring != null && ring > 0 && ring < 1) {
      canvas.drawCircle(
          at,
          _dotRadius + 10 * ring,
          Paint()
            ..color = colors.accent.withValues(alpha: 1 - ring)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  void _arrow(Canvas canvas, Offset from, Offset to) {
    final paint = Paint()
      ..color = colors.accentInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
    final angle = (to - from).direction;
    for (final side in const [-1, 1]) {
      canvas.drawLine(to, to - Offset.fromDirection(angle + side * 0.5, 10), paint);
    }
  }

  /// Progress of [t] through [start, end], clamped to 0..1.
  static double _segment(double t, double start, double end) =>
      ((t - start) / (end - start)).clamp(0.0, 1.0);

  @override
  bool shouldRepaint(_MiniScreenPainter old) =>
      old.layout != layout || old.gesture != gesture || old.loop != loop || old.colors != colors;
}

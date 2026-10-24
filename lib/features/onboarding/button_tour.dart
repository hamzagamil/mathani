// Hints over the real reading screen, one button at a time (specs/005-app-onboarding/contracts/
// onboarding-ui.md › ButtonTour, research R4).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../recitation/recitation_controller.dart';
import 'onboarding_controller.dart';
import 'onboarding_screen.dart';
import 'onboarding_steps.dart';

const scrimOpacity = 0.55;

/// Space between a highlighted control and the edge of its hole.
const holeInflate = 8.0;
const holeStroke = 2.0;

const _notch = 10.0;

/// The reader's controls the hints point at. The reader screen puts these keys on them.
class TourTargets {
  final index = GlobalKey(debugLabel: 'tour.index');
  final search = GlobalKey(debugLabel: 'tour.search');
  final listen = GlobalKey(debugLabel: 'tour.listen');
  final settings = GlobalKey(debugLabel: 'tour.settings');

  /// The recitation bar, which takes the Listen button's place during a recitation.
  final player = GlobalKey(debugLabel: 'tour.player');
}

/// Dims the reader except the current step's control, and explains it in a card above it. Every
/// tap is absorbed: Next never opens the control, and the page can't be turned (FR-017a).
class ButtonTour extends StatefulWidget {
  const ButtonTour({super.key, required this.targets});

  final TourTargets targets;

  @override
  State<ButtonTour> createState() => _ButtonTourState();
}

class _ButtonTourState extends State<ButtonTour> with WidgetsBindingObserver {
  Rect? _target;
  OnboardingStep? _measured;
  OnboardingStep? _scheduledFor;
  Timer? _settle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settle?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() => _scheduleMeasure();

  GlobalKey? _keyFor(OnboardingStep step) => switch (step) {
        OnboardingStep.surahIndex => widget.targets.index,
        OnboardingStep.search => widget.targets.search,
        OnboardingStep.player => (RecitationScope.maybeOf(context)?.session != null)
            ? widget.targets.player
            : widget.targets.listen,
        OnboardingStep.settings => widget.targets.settings,
        _ => null,
      };

  /// Measures after layout, and once more after the controls finish sliding in (200 ms).
  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 260), _measure);
  }

  void _measure() {
    if (!mounted) return;
    final onboarding = OnboardingScope.read(context);
    final step = onboarding?.step;
    if (onboarding == null || step == null || step.kind != StepKind.button) return;
    final target = _keyFor(step)?.currentContext?.findRenderObject();
    final mine = context.findRenderObject();
    if (target is! RenderBox || !target.attached || !target.hasSize) {
      // Nothing to point at (no such control here): go on rather than point at nothing.
      onboarding.next();
      return;
    }
    if (mine is! RenderBox || !mine.hasSize) return;
    final rect = target.localToGlobal(Offset.zero, ancestor: mine) & target.size;
    if (rect != _target || _measured != step) {
      setState(() {
        _target = rect;
        _measured = step;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = OnboardingScope.of(context);
    final step = onboarding.step;
    if (step == null || step.kind != StepKind.button) return const SizedBox.shrink();
    if (_scheduledFor != step) {
      _scheduledFor = step;
      _scheduleMeasure();
      _announce(onboarding, step);
    }
    final colors = MathaniColors.of(context);
    final target = _measured == step ? _target : null;
    final hole = target?.inflate(holeInflate);
    final size = MediaQuery.sizeOf(context);
    final above = hole == null || hole.center.dy > size.height / 2;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Absorbs every touch, and is not a control of its own for screen readers.
        ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            onLongPress: () {},
            onVerticalDragStart: (_) {},
            onHorizontalDragStart: (_) {},
            child: CustomPaint(
              painter: _ScrimPainter(
                hole: hole,
                above: above,
                scrim: Colors.black.withValues(alpha: scrimOpacity),
                ring: colors.focusRing,
                notch: colors.surfaceRaised,
              ),
            ),
          ),
        ),
        if (hole != null)
          Positioned(
            left: Space.s4,
            right: Space.s4,
            top: above ? null : hole.bottom + _notch,
            bottom: above ? size.height - hole.top + _notch : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: size.height * 0.5),
              child: _Card(onboarding: onboarding, step: step),
            ),
          ),
      ],
    );
  }

  void _announce(OnboardingController onboarding, OnboardingStep step) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final (title, _) = _texts(step, l10n);
      SemanticsService.sendAnnouncement(View.of(context),
          '${progressText(onboarding, l10n, Localizations.localeOf(context))}, $title',
          Directionality.of(context));
    });
  }
}

(String, String) _texts(OnboardingStep step, AppLocalizations l10n) => switch (step) {
      OnboardingStep.surahIndex => (l10n.tourIndexTitle, l10n.tourIndexBody),
      OnboardingStep.search => (l10n.tourSearchTitle, l10n.tourSearchBody),
      OnboardingStep.player => (l10n.tourPlayerTitle, l10n.tourPlayerBody),
      _ => (l10n.tourSettingsTitle, l10n.tourSettingsBody),
    };

/// The explanation: the text scrolls inside half the screen at most, and the buttons stay pinned
/// below it, always visible (FR-019).
class _Card extends StatelessWidget {
  const _Card({required this.onboarding, required this.step});

  final OnboardingController onboarding;
  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final (title, body) = _texts(step, l10n);
    return Material(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(Radii.md),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, Space.s3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(progressText(onboarding, l10n, Localizations.localeOf(context)),
                          style: TypeScale.caption.copyWith(color: colors.inkMuted)),
                      Semantics(
                        header: true,
                        child: Text(title, style: TypeScale.titleSm.copyWith(color: colors.ink)),
                      ),
                      const SizedBox(height: Space.s1),
                      Text(body, style: TypeScale.body.copyWith(color: colors.ink)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.s2),
            OnboardingButtons(onboarding: onboarding),
          ],
        ),
      ),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  _ScrimPainter({
    required this.hole,
    required this.above,
    required this.scrim,
    required this.ring,
    required this.notch,
  });

  final Rect? hole;

  /// The card is above the hole (else below).
  final bool above;
  final Color scrim;
  final Color ring;
  final Color notch;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Path()..addRect(Offset.zero & size);
    final hole = this.hole;
    if (hole == null) {
      canvas.drawPath(screen, Paint()..color = scrim);
      return;
    }
    final rrect = RRect.fromRectAndRadius(hole, const Radius.circular(Radii.sm));
    canvas.drawPath(
      Path.combine(PathOperation.difference, screen, Path()..addRRect(rrect)),
      Paint()..color = scrim,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = holeStroke,
    );
    // The card's notch, pointing at the control.
    final x = hole.center.dx;
    final edge = above ? hole.top : hole.bottom;
    final base = above ? edge - _notch - 1 : edge + _notch + 1;
    final tip = above ? edge - 2 : edge + 2;
    canvas.drawPath(
      Path()
        ..moveTo(x - _notch, base)
        ..lineTo(x + _notch, base)
        ..lineTo(x, tip)
        ..close(),
      Paint()..color = notch,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole != hole || old.above != above || old.scrim != scrim || old.ring != ring;
}

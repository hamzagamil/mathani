import 'dart:async';

import 'package:flutter/material.dart';

import '../khatma/group/group_link_host.dart';
import '../khatma/khatma_controller.dart';
import '../khatma/khatma_screen.dart';
import '../memorization/memorization_controller.dart';
import '../prayer_times/prayer_times_screen.dart';
import '../../shared/reader_state.dart';
import 'widget_snapshot.dart';

/// Where a widget tap goes (contracts/widget-surfaces.md › Links).
sealed class WidgetLink {
  const WidgetLink();

  /// The link of [text], or null when it is not a widget link or is malformed.
  static WidgetLink? parse(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || uri.scheme != WidgetLinks.scheme) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    switch ((uri.host, segments)) {
      case ('prayer', []):
        return const PrayerLink();
      case ('khatma', []):
        return const KhatmaLink();
      case ('khatma', ['read']):
        return const KhatmaReadLink();
      case ('mushaf', [final page]):
        final n = int.tryParse(page);
        if (n == null || n < 1 || n > 604 || '$n' != page) return null;
        return MushafLink(n);
      default:
        return null;
    }
  }
}

class PrayerLink extends WidgetLink {
  const PrayerLink();
}

class KhatmaLink extends WidgetLink {
  const KhatmaLink();
}

class KhatmaReadLink extends WidgetLink {
  const KhatmaReadLink();
}

class MushafLink extends WidgetLink {
  const MushafLink(this.page);
  final int page;
}

/// Shares one link source between the widget links and the group khatma links: the platform
/// hands the launch link over only once, so it is taken here and given to the side it belongs to.
class LinkSplitter {
  LinkSplitter(this.source);
  final LinkSource source;

  Future<String?>? _first;
  bool _widgetTook = false, _groupTook = false;

  Future<String?> _takeFirst() => _first ??= source.takeLink();

  /// Widget links only.
  late final LinkSource widgets = _Side(this, widgetSide: true);

  /// Every other link (group khatma links).
  late final LinkSource others = _Side(this, widgetSide: false);
}

class _Side implements LinkSource {
  _Side(this.splitter, {required this.widgetSide});
  final LinkSplitter splitter;
  final bool widgetSide;

  bool _belongs(String link) => (WidgetLink.parse(link) != null) == widgetSide;

  @override
  Future<String?> takeLink() async {
    final taken = widgetSide ? splitter._widgetTook : splitter._groupTook;
    if (taken) return null;
    if (widgetSide) {
      splitter._widgetTook = true;
    } else {
      splitter._groupTook = true;
    }
    final link = await splitter._takeFirst();
    return link != null && _belongs(link) ? link : null;
  }

  @override
  Stream<String> get links => splitter.source.links.where(_belongs);
}

/// Opens what a widget tap names (FR-004): Prayer Times, the Mushaf at a page, the khatma place,
/// or the Khatma screen. After the first frame; during a memorization session the link waits
/// until it ends, as group links do.
class WidgetLinkHost extends StatefulWidget {
  const WidgetLinkHost({super.key, required this.source, required this.child});
  final LinkSource source;
  final Widget child;

  @override
  State<WidgetLinkHost> createState() => _WidgetLinkHostState();
}

class _WidgetLinkHostState extends State<WidgetLinkHost> {
  StreamSubscription<String>? _subscription;
  WidgetLink? _waiting;
  MemorizationController? _memorization;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _subscription = widget.source.links.listen(_arrived);
      final first = await widget.source.takeLink();
      if (first != null) _arrived(first);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final m = MemorizationScope.maybeOf(context);
    if (m != _memorization) {
      _memorization?.removeListener(_retry);
      _memorization = m?..addListener(_retry);
    }
  }

  void _retry() {
    final w = _waiting;
    if (w != null && !(_memorization?.active ?? false)) {
      _waiting = null;
      unawaited(_open(w));
    }
  }

  void _arrived(String text) {
    final link = WidgetLink.parse(text);
    if (link == null || !mounted) return;
    if (_memorization?.active ?? false) {
      _waiting = link;
      return;
    }
    unawaited(_open(link));
  }

  Future<void> _open(WidgetLink link) async {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final reader = ReaderScope.read(context);
    final khatma = KhatmaScope.read(context);
    navigator.popUntil((route) => route.isFirst);
    switch (link) {
      case PrayerLink():
        unawaited(navigator.push(MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'prayer-times-widget'),
          builder: (_) => const PrayerTimesScreen(),
        )));
      case MushafLink(:final page):
        reader.jumpTo(reader.quran.firstAyahOnPage(page).ref, highlight: false);
      case KhatmaReadLink():
        if (khatma == null) return;
        if (!khatma.loaded) await khatma.load();
        final wird = khatma.readings
            .where((r) => r.key == KhatmaController.wirdKey)
            .firstOrNull;
        if (wird != null) {
          khatma.openReading(wird);
        } else if (mounted) {
          unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const KhatmaScreen())));
        }
      case KhatmaLink():
        if (khatma == null) return;
        unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const KhatmaScreen())));
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _memorization?.removeListener(_retry);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

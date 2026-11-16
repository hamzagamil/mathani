import 'dart:async';

import 'package:flutter/material.dart';

import '../../memorization/memorization_controller.dart';
import '../khatma_screen.dart';
import 'group_code.dart';
import 'group_screen.dart';

/// Where links come from: the platform (contracts/group-ui.md › Opening a link).
abstract interface class LinkSource {
  Future<String?> takeLink();
  Stream<String> get links;
}

/// Opens the group khatma of a link (contracts/group-ui.md › In the app): after the first frame,
/// any open sheet is closed and the Khatma screen and the group khatma are pushed over the
/// reader. During a memorization session the link waits until the session ends.
class GroupLinkHost extends StatefulWidget {
  const GroupLinkHost({super.key, required this.source, required this.child});
  final LinkSource source;
  final Widget child;

  @override
  State<GroupLinkHost> createState() => _GroupLinkHostState();
}

class _GroupLinkHostState extends State<GroupLinkHost> {
  StreamSubscription<String>? _subscription;
  String? _waiting;
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
      _open(w);
    }
  }

  void _arrived(String link) {
    final code = GroupCode.parse(link);
    if (code == null || !mounted) return;
    if (_memorization?.active ?? false) {
      _waiting = code;
      return;
    }
    _open(code);
  }

  void _open(String code) {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    navigator.push(MaterialPageRoute<void>(builder: (_) => const KhatmaScreen()));
    navigator.push(MaterialPageRoute<void>(builder: (_) => GroupScreen(code: code)));
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

// Choosing the reciter (specs/004-ayah-recitations/contracts/recitation-ui.md › Reciter sheet;
// specs/006-reciters-memorization/contracts/reciter-catalogue.md › Reciter list).
import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/reader_state.dart';
import '../search/arabic_normalizer.dart';
import 'recitation_controller.dart';

/// Whether [reciter] has the given surah downloaded, for the sheet's marker (User Story 4).
typedef DownloadedSurah = bool Function(String reciter, int surah);

/// Shows the reciter list. Picking one saves it and, during a recitation, restarts the current
/// ayah in the new voice (FR-004). [downloaded] marks reciters whose current surah is saved.
Future<void> showReciterSheet(BuildContext context, {DownloadedSurah? downloaded}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, controller) =>
            _ReciterSheet(downloaded: downloaded, controller: controller),
      ),
    );

class _ReciterSheet extends StatelessWidget {
  const _ReciterSheet({this.downloaded, required this.controller});

  final DownloadedSurah? downloaded;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final recitation = RecitationScope.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final current = recitation?.session?.reciter.id ?? reader.preferences.reciter;
    final surah = recitation?.session?.item.surah ?? reader.pageHead.surah;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s2),
            child: Text(l10n.chooseReciter,
                style: TypeScale.titleSm.copyWith(color: colors.accentInk)),
          ),
          Expanded(
            child: ReciterList(
              reciters: reader.quran.reciters,
              selectedId: current,
              controller: controller,
              rowBuilder: (context, r, selected) => ListTile(
                selected: selected,
                title: Text(r.name(arabic: arabic)),
                // The Arabic name is always shown (contract): under the English one.
                subtitle: Text(arabic
                    ? styleLabel(l10n, r.style)
                    : '${r.nameAr} · ${styleLabel(l10n, r.style)}'),
                leading: downloaded?.call(r.id, surah) ?? false
                    ? Icon(MathaniIcons.downloaded,
                        color: colors.secondary, semanticLabel: l10n.downloaded)
                    : const SizedBox(width: 24),
                trailing: selected ? Icon(MathaniIcons.check, color: colors.accentInk) : null,
                onTap: () {
                  Navigator.of(context).pop();
                  chooseReciter(reader, recitation, r);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The label of a recording style, shown after the reciter's name (specs/006 research R3).
String styleLabel(AppLocalizations l10n, RecitationStyle style) => switch (style) {
      RecitationStyle.murattal => l10n.murattal,
      RecitationStyle.mujawwad => l10n.mujawwad,
      RecitationStyle.muallim => l10n.muallim,
    };

/// Reciters sorted by name in the interface language; entries of one reciter keep their
/// catalogue order (Murattal before Mujawwad, and so on).
List<Reciter> sortedReciters(List<Reciter> reciters, {required bool arabic}) {
  String key(Reciter r) => arabic ? normalizeArabic(r.nameAr) : r.nameEn.toLowerCase();
  return [...reciters]..sort((a, b) {
      final byName = key(a).compareTo(key(b));
      return byName != 0 ? byName : a.sort.compareTo(b.sort);
    });
}

/// Whether every word of [query] starts a word of one of [r]'s names (research R5). Arabic is
/// compared after [normalizeArabic], with or without a leading «ال»; English ignoring case.
bool reciterMatches(Reciter r, String query) {
  final split = RegExp(r'[\s·()\-]+');
  List<String> arabicWords(String s) => [
        for (final w in normalizeArabic(s).split(split))
          if (w.isNotEmpty) ...[w, if (w.startsWith('ال') && w.length > 2) w.substring(2)],
      ];
  List<String> englishWords(String s) =>
      [for (final w in s.toLowerCase().split(split)) if (w.isNotEmpty) w];

  final names = [
    ...arabicWords(r.nameAr),
    ...arabicWords(r.shortAr),
    ...englishWords(r.nameEn),
    ...englishWords(r.shortEn),
  ];
  final words = [
    for (final w in [...normalizeArabic(query).split(split)]) if (w.isNotEmpty) w.toLowerCase(),
  ];
  return words.every((q) {
    final bare = q.startsWith('ال') && q.length > 2 ? q.substring(2) : q;
    return names.any((n) => n.startsWith(q) || n.startsWith(bare));
  });
}

/// One row of a [ReciterList].
typedef ReciterRowBuilder = Widget Function(BuildContext context, Reciter r, bool selected);

/// The searchable list of every reciter (specs/006 contracts/reciter-catalogue.md › Reciter
/// list), shared by the reciter sheet and the onboarding's reciter step. It is built lazily and
/// opens scrolled to [selectedId].
class ReciterList extends StatefulWidget {
  const ReciterList({
    super.key,
    required this.reciters,
    required this.selectedId,
    required this.rowBuilder,
    this.controller,
  });

  final List<Reciter> reciters;
  final String? selectedId;
  final ReciterRowBuilder rowBuilder;

  /// The list's scroll controller (the sheet's, so dragging the list drags the sheet).
  final ScrollController? controller;

  @override
  State<ReciterList> createState() => _ReciterListState();
}

class _ReciterListState extends State<ReciterList> {
  final _query = TextEditingController();
  ScrollController? _own;
  bool _scrolledToSelected = false;

  ScrollController get _controller => widget.controller ?? (_own ??= ScrollController());

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _own?.dispose();
    super.dispose();
  }

  /// Every row has the prototype's height, so the chosen row's offset is its index times the
  /// average extent once the list is laid out.
  void _scrollToSelected(List<Reciter> rows) {
    if (_scrolledToSelected) return;
    _scrolledToSelected = true;
    final index = rows.indexWhere((r) => r.id == widget.selectedId);
    if (index <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final p = _controller.position;
      final extent = (p.maxScrollExtent + p.viewportDimension) / rows.length;
      final target = (index * extent - p.viewportDimension / 3).clamp(0.0, p.maxScrollExtent);
      _controller.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final all = sortedReciters(widget.reciters, arabic: arabic);
    final query = _query.text.trim();
    final rows = query.isEmpty ? all : [for (final r in all) if (reciterMatches(r, query)) r];
    if (query.isEmpty) _scrollToSelected(rows);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s2),
          child: TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.searchReciters,
              prefixIcon: const Icon(MathaniIcons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.clearSearch,
                      icon: const Icon(MathaniIcons.clear),
                      onPressed: _query.clear,
                    ),
            ),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(Space.s4),
                  child: Text(l10n.noReciterFound,
                      textAlign: TextAlign.center,
                      style: TypeScale.body.copyWith(color: colors.inkMuted)),
                )
              : ListView.builder(
                  controller: _controller,
                  itemCount: rows.length,
                  prototypeItem: widget.rowBuilder(context, rows.first, false),
                  itemBuilder: (context, i) =>
                      widget.rowBuilder(context, rows[i], rows[i].id == widget.selectedId),
                ),
        ),
      ],
    );
  }
}

/// Saves [r] as the reciter; during a recitation, the current ayah restarts in the new voice
/// (FR-004). Shared with the onboarding's reciter step (specs/005).
void chooseReciter(ReaderController reader, RecitationController? recitation, Reciter r) {
  if (recitation != null) {
    recitation.setReciter(r.id);
  } else {
    reader.updatePreferences(reader.preferences.copyWith(reciter: r.id));
  }
}

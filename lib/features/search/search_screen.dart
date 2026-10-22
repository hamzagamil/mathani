import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';
import 'search_index.dart';

/// Arabic search over the Quran text (FR-022): diacritic- and spelling-insensitive, results with
/// the matched words highlighted and a summary of matching ayat and occurrences; a tap opens the
/// ayah in the Mushaf.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _debounce = Duration(milliseconds: 200);

  final _query = TextEditingController();
  late final Future<SearchIndex> _index = SearchIndex.load(ReaderScope.read(context).quran);
  SearchResults _results = SearchResults.empty;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _timer?.cancel();
    _timer = Timer(_debounce, () async {
      final results = (await _index).search(text);
      if (mounted && _query.text == text) setState(() => _results = results);
    });
  }

  /// «٢٥٤٧ موضعًا في ١٧٣٧ آية», or just the ayat when each matches once (FR-006).
  String _summary(AppLocalizations l10n, Locale locale) {
    final ayat = _results.ayahCount;
    final occurrences = _results.occurrences;
    if (ayat == 0) return l10n.searchNoResults;
    if (occurrences == ayat) return l10n.searchAyatCount(ayat, formatNumber(ayat, locale));
    return l10n.searchSummary(
        occurrences, formatNumber(occurrences, locale), ayat, formatNumber(ayat, locale));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final locale = Localizations.localeOf(context);
    final hasQuery = _results.query.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(MathaniIcons.back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.searchTitle),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.s4),
            child: TextField(
              controller: _query,
              autofocus: true,
              textDirection: TextDirection.rtl,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(MathaniIcons.search),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(MathaniIcons.clear),
                        tooltip: l10n.clearSearch,
                        onPressed: () {
                          _query.clear();
                          setState(() => _results = SearchResults.empty);
                        },
                      ),
              ),
            ),
          ),
          if (hasQuery)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s2),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _summary(l10n, locale),
                  style: TypeScale.caption.copyWith(color: colors.inkMuted),
                ),
              ),
            ),
          Expanded(
            child: !hasQuery
                ? Padding(
                    padding: const EdgeInsets.all(Space.s8),
                    child: Text(
                      l10n.searchEmptyHint,
                      textAlign: TextAlign.center,
                      style: TypeScale.body.copyWith(color: colors.inkMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.hits.length,
                    // Keyed by ayah: a row reused for another ayah would keep the old words.
                    itemBuilder: (context, i) => _ResultRow(
                      key: ValueKey('search-row-${_results.hits[i].ayah.id}'),
                      hit: _results.hits[i],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatefulWidget {
  const _ResultRow({super.key, required this.hit});
  final SearchHit hit;

  @override
  State<_ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends State<_ResultRow> {
  List<Word>? _words;

  @override
  void initState() {
    super.initState();
    final ref = widget.hit.ayah.ref;
    ReaderScope.read(context).quran.wordsOf(ref).then((w) {
      // Never show words that arrive for an ayah this row no longer shows.
      if (mounted && widget.hit.ayah.ref == ref) setState(() => _words = w);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.read(context);
    final colors = MathaniColors.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final english = locale.languageCode == 'en';
    final ayah = widget.hit.ayah;
    final surah = reader.quran.surahList[ayah.surah - 1];
    final words = _words;

    return InkWell(
      onTap: () {
        reader.jumpTo(ayah.ref); // highlighted for 1.5 s
        Navigator.of(context).pop();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.bookmarkTitle(
                english ? surah.nameTranslit : surah.nameAr,
                formatNumber(ayah.ayah, locale),
              ),
              style: TypeScale.caption.copyWith(color: colors.accentInk),
            ),
            if (words != null)
              Text.rich(
                TextSpan(
                  style: TypeScale.quranCard.copyWith(color: colors.ink),
                  children: [
                    for (final w in words)
                      if (!w.isAyahEnd)
                        TextSpan(
                          text: '${w.text} ',
                          style: widget.hit.matchedWordIds.contains(w.id)
                              ? TextStyle(backgroundColor: colors.selected)
                              : null,
                        ),
                  ],
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                textScaler: TextScaler.noScaling,
              )
            else
              const SizedBox(height: 38),
            Divider(color: colors.line, height: Space.s4),
          ],
        ),
      ),
    );
  }
}

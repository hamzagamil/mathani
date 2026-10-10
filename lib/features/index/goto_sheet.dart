import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../data/quran_repository.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';

/// Go to a page (1–604) or a surah and ayah (1..ayah count). Invalid input shows the valid range
/// and does not navigate (FR-012); valid input opens the target with a 1.5 s highlight.
Future<bool?> showGoToSheet(BuildContext context) => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _GoToSheet(),
    );

/// Parses Western or Eastern Arabic digits; null when not a number.
int? parseNumber(String text) {
  final western = String.fromCharCodes(text.trim().runes.map(
      (c) => c >= 0x0660 && c <= 0x0669 ? c - 0x0660 + 0x30 : (c >= 0x06F0 && c <= 0x06F9 ? c - 0x06F0 + 0x30 : c)));
  return int.tryParse(western);
}

class _GoToSheet extends StatefulWidget {
  const _GoToSheet();

  @override
  State<_GoToSheet> createState() => _GoToSheetState();
}

class _GoToSheetState extends State<_GoToSheet> {
  final _page = TextEditingController();
  final _ayah = TextEditingController();
  bool _byPage = true;
  late int _surah = ReaderScope.read(context).pageHead.surah;
  String? _error;

  @override
  void dispose() {
    _page.dispose();
    _ayah.dispose();
    super.dispose();
  }

  void _go() {
    final reader = ReaderScope.read(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    if (_byPage) {
      final page = parseNumber(_page.text);
      if (page == null || page < 1 || page > QuranRepository.pageCount) {
        setState(() => _error = l10n.pageRangeError(formatNumber(QuranRepository.pageCount, locale)));
        return;
      }
      reader.jumpTo(reader.quran.firstAyahOnPage(page).ref);
    } else {
      final count = reader.quran.surahList[_surah - 1].ayahCount;
      final ayah = parseNumber(_ayah.text);
      if (ayah == null || ayah < 1 || ayah > count) {
        setState(() => _error = l10n.ayahRangeError(formatNumber(count, locale)));
        return;
      }
      reader.jumpTo(AyahRef(_surah, ayah));
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final english = Localizations.localeOf(context).languageCode == 'en';
    final surahs = ReaderScope.read(context).quran.surahList;
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹]'))];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          Space.s4, 0, Space.s4, Space.s4 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.goTo, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: Space.s3),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(l10n.goToPage)),
              ButtonSegment(value: false, label: Text(l10n.goToSurahAyah)),
            ],
            selected: {_byPage},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _byPage = s.first;
              _error = null;
            }),
          ),
          const SizedBox(height: Space.s4),
          if (_byPage)
            TextField(
              controller: _page,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              decoration: InputDecoration(labelText: l10n.pageField),
              onSubmitted: (_) => _go(),
            )
          else ...[
            DropdownButtonFormField<int>(
              initialValue: _surah,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.surahField),
              items: [
                for (final s in surahs)
                  DropdownMenuItem(
                    value: s.number,
                    child: Text('${s.number}. ${english ? s.nameTranslit : s.nameAr}'),
                  ),
              ],
              onChanged: (v) => setState(() {
                _surah = v ?? _surah;
                _error = null;
              }),
            ),
            const SizedBox(height: Space.s3),
            TextField(
              controller: _ayah,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              decoration: InputDecoration(labelText: l10n.ayahField),
              onSubmitted: (_) => _go(),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.s2),
              child: Text(
                _error!,
                style: TypeScale.caption.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: Space.s4),
          FilledButton(onPressed: _go, child: Text(l10n.goButton)),
        ],
      ),
    );
  }
}

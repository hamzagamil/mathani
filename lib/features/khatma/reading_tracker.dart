// Keeping the place of a reading (specs/014 research R3, contracts/khatma-ui-and-reminders.md ›
// The place). Plain Dart: no Flutter imports.

/// What a move did to the reading.
enum TrackResult {
  /// Nothing changed.
  none,

  /// The place moved.
  moved,

  /// The reader, reading on from the place, turned past the reading's last page.
  passedEnd,
}

/// The place of one reading: the current wird, or a group part the reader holds. The place moves
/// with the reader while they turn pages from it, and stays behind when they go somewhere else.
///
/// "Pages on screen" are one page, or the two facing pages of specs/012 ([firstOnScreen] and
/// [lastOnScreen]).
class ReadingTracker {
  ReadingTracker({
    required this.firstPage,
    required this.lastPage,
    required int place,
    this.marksOnPass = true,
  })  : assert(firstPage <= lastPage),
        _place = place.clamp(firstPage, lastPage);

  final int firstPage;
  final int lastPage;

  /// False for a group part: it is marked as read only by a tap (FR-052), never by reading on.
  final bool marksOnPass;

  int _place;
  bool _following = false;

  int get place => _place;
  bool get following => _following;

  bool _onScreen(int first, int last) => _place >= first && _place <= last;

  /// Where the reader is when the reading starts being tracked, or after a jump: the index,
  /// search, bookmarks, go-to, the similar-ayah sheet, a recitation or memorization moving the
  /// page. The place does not move.
  void onJump(int firstOnScreen, int lastOnScreen) {
    _following = _onScreen(firstOnScreen, lastOnScreen);
  }

  /// A page change. [byReader] is false for a jump, which [onJump] handles.
  TrackResult onMove(int firstOnScreen, int lastOnScreen, {required bool byReader}) {
    if (!byReader) {
      onJump(firstOnScreen, lastOnScreen);
      return TrackResult.none;
    }
    if (!_following) {
      _following = _onScreen(firstOnScreen, lastOnScreen);
      return TrackResult.none;
    }
    if (firstOnScreen > lastPage) {
      if (marksOnPass) return TrackResult.passedEnd;
      // A group part keeps its last page, and stops following until the reader comes back.
      final moved = _place != lastPage;
      _place = lastPage;
      _following = false;
      return moved ? TrackResult.moved : TrackResult.none;
    }
    final next = firstOnScreen.clamp(firstPage, lastPage);
    if (next == _place) return TrackResult.none;
    _place = next;
    return TrackResult.moved;
  }

  /// Sets the place by hand, for example to the last page after Undo.
  void setPlace(int page) => _place = page.clamp(firstPage, lastPage);
}

// The group khatma as the server sends it (specs/014 contracts/group-api.md › Shapes). Plain Dart.

enum PartState { free, taken, read }

enum GroupRole { organiser, participant, viewer }

class GroupPart {
  const GroupPart({required this.n, required this.state, this.holder, this.readAt});

  factory GroupPart.fromJson(Map<String, Object?> j) => GroupPart(
        n: j['n'] as int,
        state: PartState.values.firstWhere((s) => s.name == j['state'], orElse: () => PartState.free),
        holder: j['holder'] as String?,
        readAt: j['readAt'] as int?,
      );

  final int n;
  final PartState state;
  final String? holder;
  final int? readAt;

  Map<String, Object?> toJson() => {'n': n, 'state': state.name, 'holder': holder, 'readAt': readAt};

  GroupPart copyWith({PartState? state, String? Function()? holder, int? Function()? readAt}) =>
      GroupPart(
        n: n,
        state: state ?? this.state,
        holder: holder == null ? this.holder : holder(),
        readAt: readAt == null ? this.readAt : readAt(),
      );
}

class Participant {
  const Participant({required this.id, required this.name, this.typed = false});

  factory Participant.fromJson(Map<String, Object?> j) =>
      Participant(id: j['id'] as String, name: j['name'] as String, typed: j['typed'] == true);

  final String id;
  final String name;

  /// A name the organiser typed for someone who does not use the link (FR-070).
  final bool typed;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'typed': typed};
}

/// One group khatma's state: the answer to every read and write (research R17).
class Snapshot {
  const Snapshot({
    required this.code,
    required this.title,
    required this.division,
    required this.version,
    required this.createdAt,
    required this.parts,
    required this.participants,
    this.finishDate,
    this.completedAt,
    this.organiser,
    this.you,
    this.role = GroupRole.viewer,
  });

  factory Snapshot.fromJson(Map<String, Object?> j) {
    final you = (j['you'] as Map?)?.cast<String, Object?>() ?? const {};
    return Snapshot(
      code: j['code'] as String,
      title: j['title'] as String,
      division: j['division'] as int,
      finishDate: j['finishDate'] as String?,
      version: j['version'] as int,
      createdAt: j['createdAt'] as int,
      completedAt: j['completedAt'] as int?,
      organiser: j['organiser'] as String?,
      parts: [for (final p in (j['parts'] as List)) GroupPart.fromJson((p as Map).cast())],
      participants: [
        for (final p in (j['participants'] as List)) Participant.fromJson((p as Map).cast()),
      ],
      you: you['id'] as String?,
      role: GroupRole.values.firstWhere((r) => r.name == you['role'], orElse: () => GroupRole.viewer),
    );
  }

  final String code;
  final String title;

  /// 30 ajza' or 60 ahzab.
  final int division;
  final String? finishDate;
  final int version;
  final int createdAt;
  final int? completedAt;

  /// The organiser's participant id.
  final String? organiser;
  final List<GroupPart> parts;
  final List<Participant> participants;

  /// The reader's own participant id, when they joined.
  final String? you;
  final GroupRole role;

  bool get isOrganiser => role == GroupRole.organiser;
  bool get complete => completedAt != null;

  int count(PartState s) => parts.where((p) => p.state == s).length;

  Participant? participant(String? id) {
    if (id == null) return null;
    for (final p in participants) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// The parts the reader holds.
  List<GroupPart> get mine => you == null ? const [] : [for (final p in parts) if (p.holder == you) p];

  Map<String, Object?> toJson() => {
        'code': code,
        'title': title,
        'division': division,
        'finishDate': finishDate,
        'version': version,
        'createdAt': createdAt,
        'completedAt': completedAt,
        'organiser': organiser,
        'parts': [for (final p in parts) p.toJson()],
        'participants': [for (final p in participants) p.toJson()],
        'you': {'id': you, 'role': role.name},
      };

  Snapshot withPart(GroupPart part) => Snapshot(
        code: code,
        title: title,
        division: division,
        finishDate: finishDate,
        version: version,
        createdAt: createdAt,
        completedAt: completedAt,
        organiser: organiser,
        parts: [for (final p in parts) p.n == part.n ? part : p],
        participants: participants,
        you: you,
        role: role,
      );
}

/// Why the server refused a name or a title (contracts/group-api.md › Checks).
class Problem {
  const Problem(this.field, this.kind);
  final String field;

  /// empty, long, characters, link, word or value.
  final String kind;
}

/// A part's range in the app's own Mushaf data: juz [n] of 30, or hizb [n] of 60 (research R22).
({int firstAyah, int lastAyah}) partRange({
  required int division,
  required int n,
  required List<int> juzStarts,
  required List<int> quarterStarts,
  required int ayahCount,
}) {
  final starts = division == 30
      ? juzStarts
      : [for (var i = 0; i < quarterStarts.length; i += 4) quarterStarts[i]];
  final first = starts[n - 1];
  final last = n < starts.length ? starts[n] - 1 : ayahCount;
  return (firstAyah: first, lastAyah: last);
}

import 'prayer_time_zones.dart';

// Schema 2 of the prayer state (specs/009 data-model.md). City-level places live in user.db,
// not secure storage (research R6).

enum PrayerKind { fajr, sunrise, dhuhr, asr, maghrib, isha, qiyam }

const dailyPrayers = {
  PrayerKind.fajr,
  PrayerKind.dhuhr,
  PrayerKind.asr,
  PrayerKind.maghrib,
  PrayerKind.isha,
};

enum PrayerMethod {
  muslimWorldLeague('muslim_world_league'),
  egyptian('egyptian'),
  ummAlQura('umm_al_qura'),
  karachi('karachi'),
  isna('isna'),
  dubai('dubai'),
  kuwait('kuwait'),
  qatar('qatar'),
  singapore('singapore'),
  turkey('turkey'),
  moonsightingCommittee('moonsighting_committee');

  const PrayerMethod(this.id);
  final String id;
}

enum AsrSetting { standard, hanafi }

enum HighLatitudeRule {
  middleOfNight('middle_of_night'),
  seventhOfNight('seventh_of_night');

  const HighLatitudeRule(this.id);
  final String id;

  /// The library's recommendation: one-seventh above 48°, middle of the night otherwise.
  static HighLatitudeRule recommended(double latitude) =>
      latitude.abs() > 48 ? seventhOfNight : middleOfNight;
}

enum PlaceSource { location, search, estimate }

enum EventStatus { normal, adjusted, unavailable }

enum Adjustment { highLatitude, offset }

enum AthanLength { opening, full }

enum DownloadStatus { absent, downloading, ready, failed }

/// The value of [PrayerState.current] when the current place is "My location".
const myLocationKey = 'myLocation';
const toneSound = 'tone', silentSound = 'silent';

/// Positions are kept to about 1 km (2 decimal places) before they are saved or sent (R4).
double roundCoordinate(double value) => (value * 100).round() / 100;

T _byName<T extends Enum>(Iterable<T> values, Object? raw) => values.firstWhere(
  (v) => v.name == raw,
  orElse: () => throw const FormatException('Unknown prayer value'),
);

final _controlCharacters = RegExp(r'[\x00-\x1F\x7F]');

/// Whether [value] is a valid place name: 1–80 characters, trimmed, no control characters.
bool validPlaceName(String value) {
  final text = value.trim();
  return text.isNotEmpty &&
      text.length <= 80 &&
      !_controlCharacters.hasMatch(text);
}

class CalculationSettings {
  CalculationSettings({
    this.method = PrayerMethod.muslimWorldLeague,
    this.methodChosen = false,
    this.asr = AsrSetting.standard,
    this.highLatitudeRule = HighLatitudeRule.middleOfNight,
    Map<PrayerKind, int> offsets = const {},
  }) : offsets = Map.unmodifiable({
         for (final e in offsets.entries)
           if (e.value != 0) e.key: e.value,
       }) {
    for (final e in this.offsets.entries) {
      if (!dailyPrayers.contains(e.key) || e.value < -30 || e.value > 30) {
        throw const FormatException('Invalid prayer offset');
      }
    }
  }

  /// A new place's settings: the country's usual method and the latitude's usual rule.
  factory CalculationSettings.suggested(String countryCode, double latitude) =>
      CalculationSettings(
        method: suggestion(countryCode),
        highLatitudeRule: HighLatitudeRule.recommended(latitude),
      );

  final PrayerMethod method;

  /// False while [method] is still the automatic country suggestion (R4).
  final bool methodChosen;
  final AsrSetting asr;
  final HighLatitudeRule highLatitudeRule;

  /// Minutes added to each prayer, −30..30. Missing key = 0.
  final Map<PrayerKind, int> offsets;

  int offset(PrayerKind kind) => offsets[kind] ?? 0;

  /// The method commonly used in a country (research R2). A suggestion the reader can change.
  static PrayerMethod suggestion(String countryCode) => switch (countryCode) {
    'EG' => PrayerMethod.egyptian,
    'SA' || 'YE' => PrayerMethod.ummAlQura,
    'AE' => PrayerMethod.dubai,
    'KW' => PrayerMethod.kuwait,
    'QA' => PrayerMethod.qatar,
    'TR' => PrayerMethod.turkey,
    'SG' || 'MY' || 'BN' || 'ID' => PrayerMethod.singapore,
    'PK' || 'BD' || 'IN' || 'AF' => PrayerMethod.karachi,
    'US' || 'CA' => PrayerMethod.isna,
    'GB' || 'IE' => PrayerMethod.moonsightingCommittee,
    _ => PrayerMethod.muslimWorldLeague,
  };

  CalculationSettings copyWith({
    PrayerMethod? method,
    bool? methodChosen,
    AsrSetting? asr,
    HighLatitudeRule? highLatitudeRule,
    Map<PrayerKind, int>? offsets,
  }) => CalculationSettings(
    method: method ?? this.method,
    methodChosen: methodChosen ?? this.methodChosen,
    asr: asr ?? this.asr,
    highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
    offsets: offsets ?? this.offsets,
  );

  Map<String, Object?> toJson() => {
    'method': method.id,
    'methodChosen': methodChosen,
    'asr': asr.name,
    'highLatitudeRule': highLatitudeRule.id,
    'offsets': {for (final e in offsets.entries) e.key.name: e.value},
  };

  factory CalculationSettings.fromJson(Map<String, dynamic> j) =>
      CalculationSettings(
        method: PrayerMethod.values.firstWhere(
          (v) => v.id == j['method'],
          orElse: () => throw const FormatException('Unknown prayer method'),
        ),
        methodChosen: j['methodChosen'] as bool? ?? false,
        asr: _byName(AsrSetting.values, j['asr']),
        highLatitudeRule: HighLatitudeRule.values.firstWhere(
          (v) => v.id == j['highLatitudeRule'],
          orElse: () => throw const FormatException('Unknown latitude rule'),
        ),
        offsets: {
          for (final e in (j['offsets'] as Map? ?? const {}).entries)
            _byName(PrayerKind.values, e.key): e.value as int,
        },
      );

  @override
  bool operator ==(Object other) =>
      other is CalculationSettings &&
      other.method == method &&
      other.methodChosen == methodChosen &&
      other.asr == asr &&
      other.highLatitudeRule == highLatitudeRule &&
      other.offsets.length == offsets.length &&
      offsets.entries.every((e) => other.offsets[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
    method,
    methodChosen,
    asr,
    highLatitudeRule,
    Object.hashAllUnordered(offsets.entries.map((e) => (e.key, e.value))),
  );
}

class Place {
  Place({
    required this.id,
    required String name,
    required double latitude,
    required double longitude,
    required this.timezoneId,
    required this.source,
    required this.calculation,
    this.city = '',
    this.region = '',
    this.countryCode = '',
  }) : name = name.trim(),
       latitude = roundCoordinate(latitude),
       longitude = roundCoordinate(longitude) {
    if (id.isEmpty || !validPlaceName(this.name)) {
      throw const FormatException('Invalid place name or ID');
    }
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('Invalid coordinates');
    }
    if (countryCode.isNotEmpty &&
        !RegExp(r'^[A-Z]{2}$').hasMatch(countryCode)) {
      throw const FormatException('Invalid country');
    }
    try {
      prayerTimeZone(timezoneId);
    } on Object {
      throw const FormatException('Unknown time zone');
    }
  }

  final String id, name, city, region, countryCode, timezoneId;
  final double latitude, longitude;
  final PlaceSource source;
  final CalculationSettings calculation;

  /// A place from a location endpoint result (contracts/location-api.md › Place object).
  factory Place.fromResult(
    Map<String, dynamic> r, {
    required String id,
    CalculationSettings? calculation,
  }) {
    final latitude = (r['latitude'] as num).toDouble();
    final longitude = (r['longitude'] as num).toDouble();
    final city = (r['city'] as String? ?? '').trim();
    final country = r['countryCode'] as String? ?? '';
    return Place(
      id: id,
      name: city.isNotEmpty
          ? (city.length > 80 ? city.substring(0, 80) : city)
          : '${roundCoordinate(latitude)}, ${roundCoordinate(longitude)}',
      city: city,
      region: r['region'] as String? ?? '',
      countryCode: country,
      latitude: latitude,
      longitude: longitude,
      timezoneId: r['timezoneId'] as String,
      source: _byName(PlaceSource.values, r['source']),
      calculation:
          calculation ?? CalculationSettings.suggested(country, latitude),
    );
  }

  Place copyWith({String? name, CalculationSettings? calculation}) => Place(
    id: id,
    name: name ?? this.name,
    city: city,
    region: region,
    countryCode: countryCode,
    latitude: latitude,
    longitude: longitude,
    timezoneId: timezoneId,
    source: source,
    calculation: calculation ?? this.calculation,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'city': city,
    'region': region,
    'countryCode': countryCode,
    'latitude': latitude,
    'longitude': longitude,
    'timezoneId': timezoneId,
    'source': source.name,
    'calculation': calculation.toJson(),
  };

  factory Place.fromJson(Map<String, dynamic> j) => Place(
    id: j['id'] as String,
    name: j['name'] as String,
    city: j['city'] as String? ?? '',
    region: j['region'] as String? ?? '',
    countryCode: j['countryCode'] as String? ?? '',
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    timezoneId: j['timezoneId'] as String,
    source: _byName(PlaceSource.values, j['source']),
    calculation: CalculationSettings.fromJson(
      Map<String, dynamic>.from(j['calculation'] as Map),
    ),
  );
}

class AlertSettings {
  AlertSettings({
    Set<PrayerKind> prayers = const {},
    this.sound = toneSound,
    this.athan = AthanLength.opening,
    this.qiyam = false,
  }) : prayers = Set.unmodifiable(prayers) {
    if (!dailyPrayers.containsAll(prayers) ||
        !RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(sound)) {
      throw const FormatException('Invalid alert settings');
    }
  }

  /// Prayers with an alert. Never sunrise.
  final Set<PrayerKind> prayers;

  /// A recitation id, [toneSound] or [silentSound].
  final String sound;
  final AthanLength athan;
  final bool qiyam;

  bool get any => prayers.isNotEmpty || qiyam;

  AlertSettings copyWith({
    Set<PrayerKind>? prayers,
    String? sound,
    AthanLength? athan,
    bool? qiyam,
  }) => AlertSettings(
    prayers: prayers ?? this.prayers,
    sound: sound ?? this.sound,
    athan: athan ?? this.athan,
    qiyam: qiyam ?? this.qiyam,
  );

  Map<String, Object?> toJson() => {
    'prayers': [
      for (final p in PrayerKind.values)
        if (prayers.contains(p)) p.name,
    ],
    'sound': sound,
    'athan': athan.name,
    'qiyam': qiyam,
  };

  factory AlertSettings.fromJson(Map<String, dynamic> j) => AlertSettings(
    prayers: {
      for (final v in j['prayers'] as List? ?? const [])
        _byName(PrayerKind.values, v),
    },
    sound: j['sound'] as String? ?? toneSound,
    athan: _byName(AthanLength.values, j['athan'] ?? 'opening'),
    qiyam: j['qiyam'] as bool? ?? false,
  );
}

class PrayerState {
  PrayerState({
    List<Place> places = const [],
    this.myLocation,
    this.current,
    AlertSettings? alerts,
    this.generation = 0,
    this.movedNotice,
  }) : places = List.unmodifiable(places),
       alerts = alerts ?? AlertSettings() {
    final ids = places.map((p) => p.id).toSet();
    if (ids.length != places.length ||
        generation < 0 ||
        (myLocation != null && ids.contains(myLocation!.id))) {
      throw const FormatException('Invalid prayer state');
    }
    final valid = isSetUp
        ? (current == myLocationKey
              ? myLocation != null
              : ids.contains(current))
        : current == null;
    if (!valid) throw const FormatException('Invalid current place');
  }

  static const schemaVersion = 2;

  /// Saved places. "My location" is kept apart in [myLocation].
  final List<Place> places;

  /// The latest "My location" result.
  final Place? myLocation;

  /// [myLocationKey] or a place id. Null only when not set up.
  final String? current;
  final AlertSettings alerts;

  /// Increases on every change that affects alerts; older native alerts are ignored.
  final int generation;

  /// City to show once in a "Moved to {city}" message.
  final String? movedNotice;

  bool get isSetUp => places.isNotEmpty || myLocation != null;

  Place? get currentPlace =>
      current == myLocationKey ? myLocation : placeById(current);

  Place? placeById(String? id) {
    if (id == null) return null;
    if (myLocation?.id == id) return myLocation;
    for (final p in places) {
      if (p.id == id) return p;
    }
    return null;
  }

  static const _keep = Object();

  PrayerState copyWith({
    List<Place>? places,
    Object? myLocation = _keep,
    Object? current = _keep,
    AlertSettings? alerts,
    int? generation,
    Object? movedNotice = _keep,
  }) => PrayerState(
    places: places ?? this.places,
    myLocation: identical(myLocation, _keep)
        ? this.myLocation
        : myLocation as Place?,
    current: identical(current, _keep) ? this.current : current as String?,
    alerts: alerts ?? this.alerts,
    generation: generation ?? this.generation,
    movedNotice: identical(movedNotice, _keep)
        ? this.movedNotice
        : movedNotice as String?,
  );

  /// The same state with [generation] increased: alerts must be rebuilt.
  PrayerState bumped() => copyWith(generation: generation + 1);

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'places': places.map((p) => p.toJson()).toList(),
    'myLocation': myLocation?.toJson(),
    'current': current,
    'alerts': alerts.toJson(),
    'generation': generation,
    'movedNotice': movedNotice,
  };

  factory PrayerState.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unknown prayer schema');
    }
    final my = j['myLocation'];
    return PrayerState(
      places: [
        for (final p in j['places'] as List)
          Place.fromJson(Map<String, dynamic>.from(p as Map)),
      ],
      myLocation: my == null
          ? null
          : Place.fromJson(Map<String, dynamic>.from(my as Map)),
      current: j['current'] as String?,
      alerts: AlertSettings.fromJson(
        Map<String, dynamic>.from(j['alerts'] as Map? ?? const {}),
      ),
      generation: j['generation'] as int? ?? 0,
      movedNotice: j['movedNotice'] as String?,
    );
  }
}

class PrayerEvent {
  const PrayerEvent(
    this.kind,
    this.atUtc, {
    this.status = EventStatus.normal,
    this.adjustedBy = const {},
    this.reason,
  });
  final PrayerKind kind;

  /// Null when [status] is unavailable.
  final DateTime? atUtc;
  final EventStatus status;
  final Set<Adjustment> adjustedBy;
  final String? reason;
}

class DaySchedule {
  DaySchedule({
    required this.placeId,
    required this.localDate,
    required this.timezoneId,
    required List<PrayerEvent> events,
    this.qiyamUtc,
    this.qiyamUnavailableReason,
  }) : events = List.unmodifiable(events);

  final String placeId, timezoneId;

  /// The date in the place's zone, as a UTC midnight.
  final DateTime localDate;

  /// Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha.
  final List<PrayerEvent> events;

  /// Start of the last third of the night after this day's Maghrib.
  final DateTime? qiyamUtc;
  final String? qiyamUnavailableReason;

  PrayerEvent event(PrayerKind kind) =>
      events.firstWhere((e) => e.kind == kind);
}

/// One alert handed to the platform (data model → Alert).
class Alert {
  const Alert({
    required this.id,
    required this.kind,
    required this.atUtc,
    required this.title,
    required this.body,
    required this.sound,
    required this.generation,
    this.full = false,
    this.fullPath,
  });
  final int id;
  final PrayerKind kind;
  final DateTime atUtc;
  final String title, body, sound;
  final int generation;
  final bool full;

  /// Android only: the downloaded full recording.
  final String? fullPath;

  Map<String, Object?> toMap() => {
    'id': id,
    'kind': kind.name,
    'atUtcMs': atUtc.millisecondsSinceEpoch,
    'title': title,
    'body': body,
    'sound': sound,
    'full': full,
    'fullPath': fullPath,
  };
}

/// A catalogue entry (data model → AthanRecording).
class AthanRecording {
  const AthanRecording({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.reciter,
    required this.openingEndMs,
    required this.fullUrl,
    required this.fullSha256,
    required this.fullBytes,
    required this.fullDurationMs,
    required this.source,
    required this.licence,
    required this.attribution,
  });
  final String id, nameAr, nameEn, reciter, fullUrl, fullSha256;
  final String source, licence, attribution;
  final int openingEndMs, fullBytes, fullDurationMs;

  String name({required bool arabic}) => arabic ? nameAr : nameEn;

  factory AthanRecording.fromJson(Map<String, dynamic> j) {
    final r = AthanRecording(
      id: j['id'] as String,
      nameAr: j['nameAr'] as String,
      nameEn: j['nameEn'] as String,
      reciter: j['reciter'] as String,
      openingEndMs: j['openingEndMs'] as int,
      fullUrl: j['fullUrl'] as String,
      fullSha256: j['fullSha256'] as String,
      fullBytes: j['fullBytes'] as int,
      fullDurationMs: j['fullDurationMs'] as int,
      source: j['source'] as String,
      licence: j['licence'] as String,
      attribution: j['attribution'] as String,
    );
    final uri = Uri.tryParse(r.fullUrl);
    if (!RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(r.id) ||
        r.id == toneSound ||
        r.id == silentSound ||
        r.nameAr.trim().isEmpty ||
        r.nameEn.trim().isEmpty ||
        r.openingEndMs <= 0 ||
        r.openingEndMs >= 30000 ||
        r.openingEndMs > r.fullDurationMs ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(r.fullSha256) ||
        r.fullBytes <= 0 ||
        r.fullBytes > 16 * 1024 * 1024 ||
        uri == null ||
        uri.scheme != 'https' ||
        !const {'get.mthani.app', 'mthani.app'}.contains(uri.host)) {
      throw const FormatException('Invalid athan recording');
    }
    return r;
  }
}

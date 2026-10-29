import 'prayer_time_zones.dart';

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
  karachi('karachi'),
  ummAlQura('umm_al_qura'),
  northAmerica('north_america');

  const PrayerMethod(this.id);
  final String id;
}

enum PrayerMadhhab { hanafi, shafii, maliki, hanbali }

enum HighLatitudeRule { middleOfNight, seventhOfNight }

enum LocationSource { device, manual, ip }

enum PrayerAvailability { available, adjusted, unavailable }

enum AthanMode { full, opening }

enum AudioAvailability { absent, downloading, verified, failed }

enum ReminderState { pending, claimed, playing, delivered, cancelled, failed }

enum ReminderClaimOwner { appAudio, systemFallback }

T _enum<T extends Enum>(Iterable<T> values, Object? raw) => values.firstWhere(
  (v) => v.name == raw,
  orElse: () => throw const FormatException('Unknown prayer preference'),
);

class CalculationPreferences {
  const CalculationPreferences({
    this.method = PrayerMethod.muslimWorldLeague,
    this.madhhab = PrayerMadhhab.shafii,
    this.highLatitudeRule = HighLatitudeRule.middleOfNight,
    this.conventionVersion = 1,
  });
  final PrayerMethod method;
  final PrayerMadhhab madhhab;
  final HighLatitudeRule highLatitudeRule;
  final int conventionVersion;
  int get asrFactor => madhhab == PrayerMadhhab.hanafi ? 2 : 1;
  static PrayerMethod suggestion(String country) => switch (country) {
    'EG' => PrayerMethod.egyptian,
    'SA' => PrayerMethod.ummAlQura,
    'PK' || 'BD' => PrayerMethod.karachi,
    'US' || 'CA' => PrayerMethod.northAmerica,
    _ => PrayerMethod.muslimWorldLeague,
  };
  CalculationPreferences copyWith({
    PrayerMethod? method,
    PrayerMadhhab? madhhab,
    HighLatitudeRule? highLatitudeRule,
  }) => CalculationPreferences(
    method: method ?? this.method,
    madhhab: madhhab ?? this.madhhab,
    highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
    conventionVersion: conventionVersion,
  );
  Map<String, Object?> toJson() => {
    'method': method.id,
    'madhhab': madhhab.name,
    'highLatitudeRule': highLatitudeRule.name,
    'conventionVersion': conventionVersion,
  };
  factory CalculationPreferences.fromJson(Map<String, dynamic> j) {
    final version = j['conventionVersion'] as int? ?? 1;
    if (version != 1) {
      throw const FormatException('Unknown calculation convention');
    }
    return CalculationPreferences(
      method: PrayerMethod.values.firstWhere(
        (v) => v.id == j['method'],
        orElse: () => throw const FormatException('Unknown prayer method'),
      ),
      madhhab: _enum(PrayerMadhhab.values, j['madhhab']),
      highLatitudeRule: _enum(HighLatitudeRule.values, j['highLatitudeRule']),
      conventionVersion: version,
    );
  }
}

class SavedLocation {
  SavedLocation({
    required this.id,
    required String label,
    required this.latitude,
    required this.longitude,
    required this.timezoneId,
    required this.source,
    required DateTime confirmedAtUtc,
    this.city = '',
    this.region = '',
    this.countryCode = '',
    bool approximate = false,
    this.accuracyMeters,
    this.geonamesId,
    this.calculation = const CalculationPreferences(),
  }) : label = label.trim(),
       confirmedAtUtc = confirmedAtUtc.toUtc(),
       approximate = approximate || source == LocationSource.ip {
    if (id.isEmpty ||
        this.label.isEmpty ||
        this.label.length > 80 ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(this.label)) {
      throw const FormatException('Invalid location label or ID');
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
    if (accuracyMeters != null &&
        (!accuracyMeters!.isFinite || accuracyMeters! < 0)) {
      throw const FormatException('Invalid location accuracy');
    }
    try {
      prayerTimeZone(timezoneId);
    } on Object {
      throw const FormatException('Unresolved location timezone');
    }
  }
  final String id, label, city, region, countryCode, timezoneId;
  final double latitude, longitude;
  final LocationSource source;
  final bool approximate;
  final double? accuracyMeters;
  final String? geonamesId;
  final DateTime confirmedAtUtc;
  final CalculationPreferences calculation;
  SavedLocation copyWith({
    String? label,
    CalculationPreferences? calculation,
  }) => SavedLocation(
    id: id,
    label: label ?? this.label,
    city: city,
    region: region,
    countryCode: countryCode,
    latitude: latitude,
    longitude: longitude,
    timezoneId: timezoneId,
    source: source,
    confirmedAtUtc: confirmedAtUtc,
    approximate: approximate,
    accuracyMeters: accuracyMeters,
    geonamesId: geonamesId,
    calculation: calculation ?? this.calculation,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'city': city,
    'region': region,
    'countryCode': countryCode,
    'latitude': latitude,
    'longitude': longitude,
    'timezoneId': timezoneId,
    'source': source.name,
    'approximate': approximate,
    'accuracyMeters': accuracyMeters,
    'geonamesId': geonamesId,
    'confirmedAtUtc': confirmedAtUtc.toIso8601String(),
    'calculation': calculation.toJson(),
  };
  factory SavedLocation.fromJson(Map<String, dynamic> j) => SavedLocation(
    id: j['id'] as String,
    label: j['label'] as String,
    city: j['city'] as String? ?? '',
    region: j['region'] as String? ?? '',
    countryCode: j['countryCode'] as String? ?? '',
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    timezoneId: j['timezoneId'] as String,
    source: _enum(LocationSource.values, j['source']),
    approximate: j['approximate'] as bool? ?? false,
    accuracyMeters: (j['accuracyMeters'] as num?)?.toDouble(),
    geonamesId: j['geonamesId'] as String?,
    confirmedAtUtc: DateTime.parse(j['confirmedAtUtc'] as String),
    calculation: CalculationPreferences.fromJson(
      Map<String, dynamic>.from(j['calculation'] as Map),
    ),
  );
}

class PrayerEvent {
  const PrayerEvent(
    this.kind,
    this.dueAtUtc, {
    this.availability = PrayerAvailability.available,
    this.reason,
    this.adjustmentLabel,
  });
  final PrayerKind kind;
  final DateTime? dueAtUtc;
  final PrayerAvailability availability;
  final String? reason, adjustmentLabel;
}

class DailyPrayerSchedule {
  DailyPrayerSchedule({
    required this.locationId,
    required this.localDate,
    required this.timezoneId,
    required List<PrayerEvent> events,
    required this.fingerprint,
    required this.generatedAtUtc,
    this.calculationVersion = 1,
    this.followingFajrUtc,
    this.qiyamUtc,
    this.qiyamReason,
  }) : events = List.unmodifiable(events);
  final String locationId, timezoneId, fingerprint;
  final DateTime localDate, generatedAtUtc;
  final int calculationVersion;
  final List<PrayerEvent> events;
  final DateTime? followingFajrUtc, qiyamUtc;
  final String? qiyamReason;
}

class ReminderPreferences {
  ReminderPreferences({
    Set<PrayerKind> enabledPrayers = const {},
    this.selectedAthanId = 'beautiful-adhan',
    this.requestedMode = AthanMode.opening,
    this.qiyamEnabled = false,
    Map<String, int> acknowledgedFallbacks = const {},
  }) : enabledPrayers = Set.unmodifiable(enabledPrayers),
       acknowledgedFallbacks = Map.unmodifiable(acknowledgedFallbacks) {
    if (!dailyPrayers.containsAll(enabledPrayers) || selectedAthanId.isEmpty) {
      throw const FormatException('Invalid reminder preferences');
    }
  }
  final Set<PrayerKind> enabledPrayers;
  final String selectedAthanId;
  final AthanMode requestedMode;
  final bool qiyamEnabled;
  final Map<String, int> acknowledgedFallbacks;
  bool get anyEnabled => enabledPrayers.isNotEmpty || qiyamEnabled;
  Map<String, Object?> toJson() => {
    'enabledPrayers': enabledPrayers.map((v) => v.name).toList(),
    'selectedAthanId': selectedAthanId,
    'requestedMode': requestedMode.name,
    'qiyamEnabled': qiyamEnabled,
    'acknowledgedFallbacks': acknowledgedFallbacks,
  };
  factory ReminderPreferences.fromJson(Map<String, dynamic> j) =>
      ReminderPreferences(
        enabledPrayers: (j['enabledPrayers'] as List? ?? [])
            .map((v) => _enum(PrayerKind.values, v))
            .toSet(),
        selectedAthanId: j['selectedAthanId'] as String? ?? 'beautiful-adhan',
        requestedMode: _enum(AthanMode.values, j['requestedMode'] ?? 'opening'),
        qiyamEnabled: j['qiyamEnabled'] as bool? ?? false,
        acknowledgedFallbacks: (j['acknowledgedFallbacks'] as Map? ?? {}).map(
          (k, v) => MapEntry(k as String, v as int),
        ),
      );
}

class PrayerState {
  PrayerState({
    this.schemaVersion = 1,
    this.revision = 0,
    this.generation = 0,
    this.calculationVersion = 1,
    List<SavedLocation> locations = const [],
    this.activeLocationId,
    ReminderPreferences? reminders,
  }) : locations = List.unmodifiable(locations),
       reminders = reminders ?? ReminderPreferences() {
    if (schemaVersion != 1 ||
        revision < 0 ||
        generation < 0 ||
        calculationVersion != 1 ||
        locations.map((v) => v.id).toSet().length != locations.length ||
        (activeLocationId != null &&
            !locations.any((v) => v.id == activeLocationId)) ||
        (this.reminders.anyEnabled && activeLocationId == null)) {
      throw const FormatException('Invalid or unsupported prayer snapshot');
    }
  }
  final int schemaVersion, revision, generation, calculationVersion;
  final List<SavedLocation> locations;
  final String? activeLocationId;
  final ReminderPreferences reminders;
  SavedLocation? get activeLocation => activeLocationId == null
      ? null
      : locations.firstWhere((v) => v.id == activeLocationId);
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'revision': revision,
    'generation': generation,
    'calculationVersion': calculationVersion,
    'locations': locations.map((v) => v.toJson()).toList(),
    'activeLocationId': activeLocationId,
    'reminders': reminders.toJson(),
  };
  factory PrayerState.fromJson(Map<String, dynamic> j) => PrayerState(
    schemaVersion: j['schemaVersion'] as int,
    revision: j['revision'] as int,
    generation: j['generation'] as int? ?? 0,
    calculationVersion: j['calculationVersion'] as int? ?? 1,
    locations: (j['locations'] as List)
        .map((v) => SavedLocation.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList(),
    activeLocationId: j['activeLocationId'] as String?,
    reminders: ReminderPreferences.fromJson(
      Map<String, dynamic>.from(j['reminders'] as Map),
    ),
  );
}

class AthanRecording {
  const AthanRecording({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.creditedRecorder,
    required this.sourceUrl,
    required this.sourceRevision,
    required this.licenseId,
    required this.licenseUrl,
    required this.changeNotice,
    required this.fullAssetUrl,
    required this.sha256,
    required this.expectedBytes,
    required this.durationMs,
    required this.encoding,
    required this.openingAssetId,
    required this.openingEndMs,
    required this.openingDurationMs,
    required this.platformClipHashes,
    required this.platformClipEncodings,
    this.completeRecordingReviewed = false,
    this.fourTakbirsReviewed = false,
  });
  final String id,
      titleAr,
      titleEn,
      creditedRecorder,
      sourceUrl,
      sourceRevision;
  final String licenseId,
      licenseUrl,
      changeNotice,
      fullAssetUrl,
      sha256,
      encoding,
      openingAssetId;
  final int expectedBytes, durationMs, openingEndMs, openingDurationMs;
  final Map<String, String> platformClipHashes, platformClipEncodings;
  final bool completeRecordingReviewed, fourTakbirsReviewed;
  bool get iosShortEligible =>
      completeRecordingReviewed &&
      fourTakbirsReviewed &&
      openingDurationMs > 0 &&
      openingDurationMs < 30000;
}

class ReminderCapability {
  const ReminderCapability({
    required this.permissionStatus,
    this.exactAlarmAccess = false,
    this.foregroundModes = const {},
    this.backgroundModes = const {},
    this.reason,
    this.recoveryAction,
    this.channelRestricted,
    this.scheduledThroughUtc,
    this.appMustReopenByUtc,
  });
  final String permissionStatus;
  final bool exactAlarmAccess;
  final Set<AthanMode> foregroundModes, backgroundModes;
  final bool? channelRestricted;
  final String? reason, recoveryAction;
  final DateTime? scheduledThroughUtc, appMustReopenByUtc;
}

class ScheduledReminder {
  const ScheduledReminder({
    required this.eventId,
    required this.locationId,
    required this.generation,
    required this.kind,
    required this.dueAtUtc,
    required this.expiresAtUtc,
    required this.audioId,
    required this.mode,
    required this.deliveryMechanism,
    this.state = ReminderState.pending,
    this.claimOwner,
    this.consumed = false,
  });
  final String eventId, locationId, audioId, deliveryMechanism;
  final int generation;
  final PrayerKind kind;
  final DateTime dueAtUtc, expiresAtUtc;
  final AthanMode mode;
  final ReminderState state;
  final ReminderClaimOwner? claimOwner;
  final bool consumed;
}

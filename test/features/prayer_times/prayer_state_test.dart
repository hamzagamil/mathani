import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_repository.dart';

import '../../support/prayer_fakes.dart';

void main() {
  PrayerState sample() => PrayerState(
    places: [
      place(
        cairoResult(),
        calculation: CalculationSettings(
          method: PrayerMethod.egyptian,
          methodChosen: true,
          asr: AsrSetting.hanafi,
          offsets: {PrayerKind.isha: 5},
        ),
      ),
    ],
    myLocation: place(londonResult(source: 'location'), id: 'me'),
    current: myLocationKey,
    alerts: AlertSettings(
      prayers: {PrayerKind.fajr, PrayerKind.isha},
      athan: AthanLength.full,
      qiyam: true,
    ),
    generation: 7,
    movedNotice: 'London',
  );

  test('schema 2 round-trips through JSON', () {
    final s = sample();
    final back = PrayerState.fromJson(
      jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
    );
    expect(jsonEncode(back.toJson()), jsonEncode(s.toJson()));
    expect(back.currentPlace!.id, 'me');
    expect(back.places.single.calculation.offset(PrayerKind.isha), 5);
  });

  test('validation: sunrise alerts, bad names and a dangling current place '
      'are rejected', () {
    expect(
      () => AlertSettings(prayers: {PrayerKind.sunrise}),
      throwsFormatException,
    );
    expect(
      () => place(cairoResult()).copyWith(name: ' '),
      throwsFormatException,
    );
    expect(
      () => place(cairoResult()).copyWith(name: 'a' * 81),
      throwsFormatException,
    );
    expect(
      () => PrayerState(places: [place(cairoResult())], current: 'nope'),
      throwsFormatException,
    );
    expect(() => PrayerState(current: myLocationKey), throwsFormatException);
  });

  test('not set up: no places and no My location', () {
    expect(PrayerState().isSetUp, isFalse);
    expect(PrayerState().currentPlace, isNull);
  });

  test('a missing value loads as not set up', () async {
    final s = await PrayerRepository(MemoryPrayerStateStore()).load();
    expect(s.isSetUp, isFalse);
  });

  test('an unknown schema loads as not set up and is kept until the next '
      'save', () async {
    const newer = '{"schemaVersion": 3, "places": []}';
    final store = MemoryPrayerStateStore(newer);
    final repository = PrayerRepository(store);
    expect((await repository.load()).isSetUp, isFalse);
    expect(store.value, newer);
    await repository.save(sample());
    expect(store.value, isNot(newer));
    expect((await repository.load()).generation, 7);
  });

  test('unreadable JSON loads as not set up', () async {
    final s = await PrayerRepository(MemoryPrayerStateStore('{oops')).load();
    expect(s.isSetUp, isFalse);
  });
}

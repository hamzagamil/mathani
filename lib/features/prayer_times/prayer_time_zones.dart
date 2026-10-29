import 'package:timezone/data/latest_all.dart' as data;
import 'package:timezone/timezone.dart' as tz;

bool _initialized = false;
void initializePrayerTimeZones() {
  if (_initialized) return;
  data.initializeTimeZones();
  _initialized = true;
}

tz.Location prayerTimeZone(String id) {
  initializePrayerTimeZones();
  return tz.getLocation(id);
}

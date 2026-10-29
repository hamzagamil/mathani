"""Build-time only: uv run --python 3.12 --with hijridate==2.6.0 --no-project tool/prayer/build_ramadan_table.py"""
import json
from pathlib import Path
from importlib.metadata import distribution, version
from hijridate import Hijri

ROOT = Path(__file__).resolve().parents[2]
assert version("hijridate") == "2.6.0", "Pin the reviewed calendar version"
def civil(year, month):
    value = Hijri(year, month, 1).to_gregorian()
    return f"{value.year:04d}-{value.month:02d}-{value.day:02d}"
payload = {
    "schemaVersion": 1, "conventionVersion": 1,
    "source": "https://github.com/dralshehri/hijridate",
    "sourceVersion": "2.6.0",
    "coverageStart": "2020-01-01", "coverageEndExclusive": "2038-01-01",
    "intervals": [{"year": year, "ramadanCivilStart": civil(year, 9),
                   "shawwalCivilStart": civil(year, 10)} for year in range(1440, 1460)],
}
target = ROOT / "assets/prayer/ramadan_intervals.json"
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
dist = distribution("hijridate")
licenses = [p for p in dist.files if p.name.upper() in ("LICENSE", "LICENSE.TXT", "LICENSE.MD")]
assert licenses, "Preserve the source license before shipping calendar data"
notice = ROOT / "assets/licences/LICENSE-hijridate.txt"
notice.write_text("Calendar interval data derived from HijriDate 2.6.0; no source changes.\n"
                 "https://github.com/dralshehri/hijridate\n\n"
                 + dist.locate_file(licenses[0]).read_text(encoding="utf-8"), encoding="utf-8")
print(f"Generated {len(payload['intervals'])} intervals; {payload['coverageStart']}..{payload['coverageEndExclusive']}")

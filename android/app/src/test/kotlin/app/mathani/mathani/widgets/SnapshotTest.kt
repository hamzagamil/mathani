package app.mathani.mathani.widgets

import org.junit.Assert.*
import org.junit.Test

/** specs/017 contracts/widget-snapshot.md › Validation, data-model.md › next prayer. */
class SnapshotTest {
    companion object {
        const val DAY = 86_400_000L

        fun entry(kind: String, at: Long) = """{"kind":"$kind","atUtc":$at,"name":"${kind.replaceFirstChar { it.uppercase() }}","time":"t$at"}"""

        /** Two days of five prayers, starting at [start], each day beginning at its start. */
        fun json(v: Int = 1, start: Long = 1_000_000L, entries: String? = null): String {
            val list = entries ?: (0 until 2).flatMap { d ->
                listOf("fajr", "dhuhr", "asr", "maghrib", "isha").mapIndexed { i, k -> entry(k, start + d * DAY + (i + 1) * 3_600_000L) }
            }.joinToString(",")
            return """
            {"v":$v,"madeAtUtc":5,"lang":"en","rtl":false,
             "labels":{"next":"Next prayer","setPlace":"Set your place in Prayer Times","a11yNext":"Next prayer: {name} at {time}"},
             "prayer":{"place":"Cairo","validUntilUtc":${start + DAY + 5 * 3_600_000L + 60_000},
               "days":[{"startUtc":$start,"label":"Today"},{"startUtc":${start + DAY},"label":"Monday"}],
               "entries":[$list]},
             "quran":{"mode":"wird","title":"Today's wird","line1":"From Al-Baqarah 142","line2":"to Al-Baqarah 202",
               "progress":{"percent":41,"pagesRead":248,"pagesTotal":604,"text":"41%","todayRead":false,"paused":false},
               "link":"mathani-widget://khatma/read"}}
            """.trimIndent()
        }
    }

    @Test fun parsesTheContract() {
        val s = Snapshot.parse(json())!!
        assertEquals("en", s.lang)
        assertEquals("Next prayer", s.label("next"))
        assertEquals("", s.label("missing"))
        assertEquals("Cairo", s.prayer!!.place)
        assertEquals(10, s.prayer!!.entries.size)
        assertEquals("wird", s.quran!!.mode)
        assertEquals(41, s.quran!!.progress!!.percent)
        assertEquals("mathani-widget://khatma/read", s.quran!!.link)
    }

    @Test fun rejectsANewerVersionAndBrokenText() {
        assertNull(Snapshot.parse(json(v = 2)))
        assertNull(Snapshot.parse("{"))
        assertNull(Snapshot.parse(null))
        assertNull(Snapshot.parse(""))
    }

    @Test fun rejectsEntriesOutOfOrderOrRepeated() {
        assertNull(Snapshot.parse(json(entries = entry("fajr", 20) + "," + entry("dhuhr", 10))))
        assertNull(Snapshot.parse(json(entries = entry("fajr", 20) + "," + entry("dhuhr", 20))))
    }

    @Test fun nextEntryChangesExactlyAtEachTime() {
        val p = Snapshot.parse(json())!!.prayer!!
        val dhuhr = p.entries[1].atUtc
        assertEquals("dhuhr", p.nextEntry(dhuhr - 1)!!.kind)
        assertEquals("asr", p.nextEntry(dhuhr)!!.kind)
        assertEquals("asr", p.nextEntry(dhuhr + 1)!!.kind)
        assertNull(p.nextEntry(p.entries.last().atUtc))
    }

    @Test fun expiresAtValidUntil() {
        val p = Snapshot.parse(json())!!.prayer!!
        assertFalse(p.isExpired(p.validUntilUtc - 1))
        assertTrue(p.isExpired(p.validUntilUtc))
    }

    @Test fun dayOfKeepsTheFivePrayersOfThatDay() {
        val p = Snapshot.parse(json())!!.prayer!!
        val second = p.dayOf(1_000_000L + DAY + 1)
        assertEquals(5, second.size)
        assertEquals(p.entries[5], second.first())
    }

    private class MemoryBackend : SnapshotBackend {
        val stored = mutableMapOf<String, String>()
        override fun read(key: String) = stored[key]
        override fun write(values: Map<String, String?>) {
            for ((key, value) in values) if (value == null) stored.remove(key) else stored[key] = value
        }
    }

    @Test fun storeReportsOnlyRealChanges() {
        val store = SnapshotStore(MemoryBackend())
        assertTrue(store.put(json()))
        assertFalse(store.put(json()))
        assertEquals("Cairo", store.snapshot()!!.prayer!!.place)
        store.clear()
        assertNull(store.snapshot())
    }
}

package app.mathani.wear

import org.junit.Assert.*
import org.junit.Test

/** specs/017 contracts/watch-sync.md and research R2, R7 (T046, T059). */
class PrayerTimelineTest {
    companion object {
        const val DAY = 86_400_000L
        const val START = 1_000_000L

        fun entry(kind: String, at: Long) = """{"kind":"$kind","atUtc":$at,"name":"$kind","time":"t$at"}"""

        fun copy(made: Long = 5, khatma: String = "null"): String {
            val list = (0 until 2).flatMap { d ->
                listOf("fajr", "dhuhr", "asr", "maghrib", "isha").mapIndexed { i, k -> entry(k, START + d * DAY + (i + 1) * 3_600_000L) }
            }.joinToString(",")
            return """
            {"v":1,"madeAtUtc":$made,"lang":"en","rtl":false,"labels":{"openToUpdate":"Open Mathani to update"},
             "prayer":{"place":"Cairo","validUntilUtc":${START + DAY + 5 * 3_600_000L + 60_000},
               "days":[{"startUtc":$START,"label":"Today"},{"startUtc":${START + DAY},"label":"Monday"}],
               "entries":[$list]},
             "khatma":$khatma}
            """.trimIndent()
        }
    }

    private val block = WatchCopy.parse(copy())!!.prayer!!

    @Test fun oneSlotPerPrayerThenTheEnd() {
        val now = block.entries[1].atUtc - 60_000
        val slots = prayerSlots(block, now)
        assertEquals(9 + 1, slots.size)
        assertEquals(now, slots.first().start)
        assertEquals("dhuhr", slots.first().next!!.kind)
        assertEquals(block.entries[1].atUtc, slots.first().end)
        // Each slot shows the prayer it ends at.
        slots.dropLast(1).forEach { assertEquals(it.end, it.next!!.atUtc) }
        assertNull(slots.last().next)
        assertEquals(Long.MAX_VALUE, slots.last().end)
    }

    @Test fun expiredIsOneOpenSlotWithNothing() {
        val slots = prayerSlots(block, block.validUntilUtc)
        assertEquals(1, slots.size)
        assertNull(slots.single().next)
    }

    @Test fun dayOfAPrayerIsItsDay() {
        val (label, day) = block.dayOf(block.entries[6].atUtc)
        assertEquals("Monday", label)
        assertEquals(5, day.size)
        assertEquals(block.entries[4], block.previousOf(block.entries[5]))
    }

    @Test fun newerCopyWinsOlderIsIgnored() {
        val older = WatchCopy.parse(copy(made = 5))!!
        val newer = WatchCopy.parse(copy(made = 9))!!
        assertTrue(CopyStore.isNewer(newer, older))
        assertFalse(CopyStore.isNewer(older, newer))
        assertFalse(CopyStore.isNewer(older, older))
        assertTrue(CopyStore.isNewer(older, null))
    }

    @Test fun khatmaProgressIsRead() {
        val c = WatchCopy.parse(copy(khatma = """{"percent":141,"todayRead":true,"paused":false,"text":"41%"}"""))!!
        assertEquals(100, c.khatma!!.percent)
        assertTrue(c.khatma!!.todayRead)
        assertNull(WatchCopy.parse(copy())!!.khatma)
    }

    @Test fun rejectsBrokenCopies() {
        assertNull(WatchCopy.parse("{"))
        assertNull(WatchCopy.parse(copy().replace("\"v\":1", "\"v\":2")))
        assertNull(WatchCopy.parse(null))
    }
}

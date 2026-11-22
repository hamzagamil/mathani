package app.mathani.mathani.widgets

import app.mathani.mathani.widgets.SnapshotTest.Companion.DAY
import app.mathani.mathani.widgets.SnapshotTest.Companion.json
import org.junit.Assert.*
import org.junit.Test

/** specs/017 research R3: redraw times and the medium widget's rows. */
class WidgetAlarmsTest {
    private val snapshot = Snapshot.parse(json())!!
    private val block = snapshot.prayer!!

    @Test fun nextRedrawIsTheNextPrayer() {
        val asr = block.entries[2].atUtc
        assertEquals(asr, nextRedrawAt(snapshot, block.entries[1].atUtc))
        assertEquals(asr, nextRedrawAt(snapshot, asr - 1))
    }

    @Test fun afterTheLastPrayerTheRedrawIsTheEndOfTheTimes() {
        assertEquals(block.validUntilUtc, nextRedrawAt(snapshot, block.entries.last().atUtc))
    }

    @Test fun noRedrawWhenExpiredOrWithoutTimes() {
        assertNull(nextRedrawAt(snapshot, block.validUntilUtc))
        assertNull(nextRedrawAt(null, 0))
        assertNull(nextRedrawAt(snapshot.copy(prayer = null), 0))
    }

    @Test fun mediumHighlightsTheNextPrayerOfItsDay() {
        val frame = prayerFrame(block, block.entries[2].atUtc - 1)
        assertEquals("asr", frame.next!!.kind)
        assertEquals(5, frame.day.size)
        assertEquals(2, frame.highlight)
        assertFalse(frame.expired)
    }

    @Test fun afterIshaTheMediumShowsTomorrow() {
        val frame = prayerFrame(block, block.entries[4].atUtc + 1)
        assertEquals("fajr", frame.next!!.kind)
        assertEquals(block.entries[5], frame.day.first())
        assertEquals(0, frame.highlight)
        assertTrue(frame.day.first().atUtc >= 1_000_000L + DAY)
    }

    @Test fun expiredFrameShowsNothing() {
        val frame = prayerFrame(block, block.validUntilUtc)
        assertTrue(frame.expired)
        assertNull(frame.next)
        assertTrue(frame.day.isEmpty())
    }
}

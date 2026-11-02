package app.mathani.mathani

import org.junit.Assert.*
import org.junit.Test

class PrayerAlarmStoreTest {
    private class Backend : PrayerStoreBackend {
        var value: String? = null
        override fun read() = value
        override fun write(value: String) { this.value = value }
    }

    private fun alert(id: Int, at: Long = 100_000, full: Boolean = false) =
        PrayerAlert(id, "fajr", at, "Fajr", "4:12 AM · Cairo", "tone", full, if (full) "/data/athan.m4a" else null)

    @Test fun emptyStoreHasNothing() {
        val store = PrayerAlarmStore(Backend())
        assertEquals(0L, store.generation())
        assertTrue(store.all().isEmpty())
    }

    @Test fun replaceKeepsTheNewListAndReportsRemovedIds() {
        val store = PrayerAlarmStore(Backend())
        assertEquals(emptySet<Int>(), store.replace(1, listOf(alert(1), alert(2))))
        val removed = store.replace(2, listOf(alert(2), alert(3)))
        assertEquals(setOf(1), removed)
        assertEquals(2L, store.generation())
        assertEquals(listOf(2, 3), store.all().map { it.id })
    }

    @Test fun roundTripKeepsEveryField() {
        val backend = Backend()
        val original = alert(7, full = true)
        PrayerAlarmStore(backend).replace(3, listOf(original))
        assertEquals(original, PrayerAlarmStore(backend).get(7))
    }

    @Test fun removeIsOnceOnly() {
        val store = PrayerAlarmStore(Backend())
        store.replace(1, listOf(alert(1)))
        assertTrue(store.remove(1))
        assertFalse(store.remove(1))
    }

    @Test fun futureSkipsPastAlertsInTimeOrder() {
        val store = PrayerAlarmStore(Backend())
        store.replace(1, listOf(alert(1, 300), alert(2, 100), alert(3, 200)))
        assertEquals(listOf(3, 1), store.future(150).map { it.id })
    }

    @Test fun clearRemovesAllAndKeepsTheGeneration() {
        val store = PrayerAlarmStore(Backend())
        store.replace(4, listOf(alert(1), alert(2)))
        assertEquals(setOf(1, 2), store.clear())
        assertEquals(4L, store.generation())
        assertTrue(store.all().isEmpty())
    }

    @Test fun duplicateIdsAreRejected() {
        val store = PrayerAlarmStore(Backend())
        assertThrows(IllegalArgumentException::class.java) { store.replace(1, listOf(alert(1), alert(1))) }
    }

    @Test fun unknownFormatLoadsEmpty() {
        val backend = Backend().apply { value = "00000001" + "0".repeat(24) }
        assertTrue(PrayerAlarmStore(backend).all().isEmpty())
    }
}

package app.mathani.mathani

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import javax.crypto.KeyGenerator

class PrayerAlarmStoreTest {
    private class Backend : PrayerQueueBackend {
        var bytes: ByteArray? = null
        var unlocked = true
        var failWrite = false
        val key = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
        val cipher = PrayerQueueCipher { key }
        override fun read(): ByteArray? {
            check(unlocked) { "locked" }
            return bytes?.let(cipher::decrypt)
        }
        override fun write(value: ByteArray) {
            check(unlocked && !failWrite) { "unavailable" }
            bytes = cipher.encrypt(value)
        }
    }
    private fun event(id: String = "event_a", generation: Long = 1) = PrayerAlarmEvent(
        eventId = id, locationId = "opaque_location", generation = generation,
        dueAtMs = 100_000, expiresAtMs = 160_000, kind = "fajr", assetId = "opening_a",
        mode = "opening", title = "Private location name", body = "Prayer reminder",
    )

    @Test fun encryptedPersistenceSurvivesReopening() {
        val backend = Backend()
        PrayerAlarmStore(backend).replace(1, listOf(event()), 0)
        assertFalse(String(backend.bytes!!, Charsets.ISO_8859_1).contains("Private location name"))
        val reopened = PrayerAlarmStore(backend)
        assertEquals("Private location name", reopened.future(0).single().title)
        assertEquals(1L, reopened.generation())
        val damaged = backend.bytes!!.clone().also { it[it.lastIndex] = (it.last().toInt() xor 1).toByte() }
        backend.bytes = damaged
        assertThrows(Exception::class.java) { reopened.replace(2, emptyList(), 0) }
        assertArrayEquals(damaged, backend.bytes)
    }
    @Test fun savedLocationBase64PaddingRoundTripsWithoutChangingItsIdentity() {
        val store = PrayerAlarmStore(Backend())
        val existingId = "padded_location_id=="
        store.replace(1, listOf(event().copy(locationId = existingId)), 0)
        assertEquals(existingId, store.future(0).single().locationId)
    }
    @Test fun cancelPendingRejectsOldAlarmAndAllowsSameGenerationRefill() {
        val store = PrayerAlarmStore(Backend())
        store.replace(1, listOf(event()), 0)
        store.clearPending()
        assertTrue(store.future(0).isEmpty())
        assertFalse(store.claimFallback("event_a", 1, 100_000))
        assertEquals(1L, store.generation())
        store.replace(1, listOf(event()), 0)
        assertTrue(store.claimFallback("event_a", 1, 100_000))
        assertFalse(store.claimFallback("event_a", 1, 100_000))
    }
    @Test fun systemPostIsOnceOnlyAndCancelledTokensNeverPost() {
        val store = PrayerAlarmStore(Backend())
        store.replace(1, listOf(event()), 0)
        var posts = 0
        assertTrue(store.deliverFallback("event_a", 1, 100_000) { posts++ })
        assertFalse(store.deliverFallback("event_a", 1, 100_000) { posts++ })
        assertEquals(1, posts)
        store.clearPending()
        assertFalse(store.deliverFallback("event_a", 1, 100_000) { posts++ })
        assertEquals(1, posts)
    }

    @Test fun concurrentAudioAndFallbackHaveOnlyOneFinalWinner() {
        val backend = Backend()
        val stores = listOf(PrayerAlarmStore(backend), PrayerAlarmStore(backend))
        stores[0].replace(1, listOf(event()), 0)
        assertTrue(stores[0].claimAudio("event_a", 1, 100_000))
        val start = CountDownLatch(1)
        val pool = Executors.newFixedThreadPool(2)
        try {
            val audio = pool.submit<Boolean> { start.await(); stores[0].markStarted("event_a", 1, 100_100) }
            val fallback = pool.submit<Boolean> { start.await(); stores[1].claimFallback("event_a", 1, 100_100) }
            start.countDown()
            assertTrue(audio.get() xor fallback.get())
            assertFalse(stores[0].claimAudio("event_a", 1, 100_200))
            assertFalse(stores[1].claimFallback("event_a", 1, 100_200))
        } finally { pool.shutdownNow() }
    }

    @Test fun stopRejectsLateStartAndReplacementRejectsOldGeneration() {
        val backend = Backend(); val store = PrayerAlarmStore(backend)
        store.replace(1, listOf(event()), 0)
        assertTrue(store.claimAudio("event_a", 1, 100_000))
        store.cancel("event_a", 1)
        assertFalse(store.markStarted("event_a", 1, 100_100))
        assertFalse(store.claimFallback("event_a", 1, 100_100))
        store.replace(2, listOf(event("event_b", 2)), 0)
        assertFalse(store.claimAudio("event_a", 1, 100_000))
        assertThrows(IllegalArgumentException::class.java) { store.replace(1, emptyList(), 0) }
    }

    @Test fun earlyExpiredAndLockedDeliveryFailClosedWithoutResettingData() {
        val backend = Backend(); val store = PrayerAlarmStore(backend)
        store.replace(1, listOf(event()), 0)
        assertFalse(store.claimAudio("event_a", 1, 99_999))
        assertFalse(store.claimAudio("event_a", 1, 160_001))
        assertTrue(store.future(100_001).isEmpty()) // boot skips already due events
        val bytes = backend.bytes!!.clone()
        backend.unlocked = false
        assertThrows(Exception::class.java) { store.future(0) }
        assertThrows(Exception::class.java) { store.replace(2, emptyList(), 0) }
        assertArrayEquals(bytes, backend.bytes)
        backend.unlocked = true
        assertEquals(1, store.future(0).size)
    }

    @Test fun retryingSameGenerationDoesNotReplayConsumedEvents() {
        val store = PrayerAlarmStore(Backend())
        store.replace(1, listOf(event()), 0)
        assertTrue(store.claimFallback("event_a", 1, 100_000))
        store.replace(1, listOf(event()), 0)
        assertFalse(store.claimAudio("event_a", 1, 100_001))
        assertThrows(IllegalArgumentException::class.java) { store.replace(1, listOf(event(), event()), 0) }
    }

    @Test fun failedWriteDoesNotPublishAClaimAndQueueIsBounded() {
        val backend = Backend(); val store = PrayerAlarmStore(backend)
        store.replace(1, listOf(event()), 0)
        backend.failWrite = true
        assertThrows(Exception::class.java) { store.claimAudio("event_a", 1, 100_000) }
        backend.failWrite = false
        assertTrue(store.claimFallback("event_a", 1, 100_001))
        assertThrows(IllegalArgumentException::class.java) {
            store.replace(2, (0..192).map { event("event_$it", 2) }, 0)
        }
        assertThrows(IllegalArgumentException::class.java) { store.replace(2, listOf(event("a", 2).copy(kind = "sunrise")), 0) }
    }
}

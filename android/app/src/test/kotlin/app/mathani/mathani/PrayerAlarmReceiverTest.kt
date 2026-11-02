package app.mathani.mathani

import org.junit.Assert.assertEquals
import org.junit.Test

/** The receiver's choice for a due alert (specs/009 contracts › Android receiver). */
class PrayerAlarmReceiverTest {
    private val at = 1_000_000_000L
    private fun alert(full: Boolean = false, kind: String = "dhuhr") =
        PrayerAlert(1, kind, at, "Dhuhr", "12:05 PM · Cairo", "husary", full, if (full) "/a.m4a" else null)

    private fun decide(
        alert: PrayerAlert? = alert(), generation: Long = 2, stored: Long = 2, late: Long = 0,
        file: Boolean = true, canStart: Boolean = true,
    ) = PrayerAlertRules.decide(alert, generation, stored, at + late, file, canStart)

    @Test fun onTimePosts() = assertEquals(AlertAction.POST, decide())

    @Test fun removedAlertIsIgnored() = assertEquals(AlertAction.IGNORE, decide(alert = null))

    @Test fun olderGenerationIsIgnored() = assertEquals(AlertAction.IGNORE, decide(generation = 1))

    @Test fun fourteenMinutesLatePosts() = assertEquals(AlertAction.POST, decide(late = 14 * 60_000L))

    @Test fun sixteenMinutesLateIsDropped() = assertEquals(AlertAction.DROP, decide(late = 16 * 60_000L))

    @Test fun fullWithFileAndExactAlarmsPlays() =
        assertEquals(AlertAction.PLAY_FULL, decide(alert = alert(full = true)))

    @Test fun fullWithoutTheFilePostsTheOpening() =
        assertEquals(AlertAction.POST, decide(alert = alert(full = true), file = false))

    @Test fun fullWithoutExactAlarmsOrRingerPostsTheOpening() =
        assertEquals(AlertAction.POST, decide(alert = alert(full = true), canStart = false))

    @Test fun qiyamNeverPlaysAnAthan() =
        assertEquals(AlertAction.POST, decide(alert = alert(full = true, kind = "qiyam")))
}

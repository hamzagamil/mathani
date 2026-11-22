package app.mathani.wear

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import androidx.wear.watchface.complications.data.ComplicationData
import androidx.wear.watchface.complications.data.ComplicationText
import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.CountDownTimeReference
import androidx.wear.watchface.complications.data.LongTextComplicationData
import androidx.wear.watchface.complications.data.MonochromaticImage
import androidx.wear.watchface.complications.data.NoDataComplicationData
import androidx.wear.watchface.complications.data.PlainComplicationText
import androidx.wear.watchface.complications.data.RangedValueComplicationData
import androidx.wear.watchface.complications.data.ShortTextComplicationData
import androidx.wear.watchface.complications.data.TimeDifferenceComplicationText
import androidx.wear.watchface.complications.data.TimeDifferenceStyle
import androidx.wear.watchface.complications.datasource.ComplicationDataTimeline
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import androidx.wear.watchface.complications.datasource.SuspendingComplicationDataSourceService
import androidx.wear.watchface.complications.datasource.SuspendingTimelineComplicationDataSourceService
import androidx.wear.watchface.complications.datasource.TimeInterval
import androidx.wear.watchface.complications.datasource.TimelineEntry
import java.time.Instant

private fun text(value: String): ComplicationText = PlainComplicationText.Builder(value).build()

private fun icon(context: Context) =
    MonochromaticImage.Builder(Icon.createWithResource(context, R.drawable.ic_complication)).build()

/** Every tap opens the watch app's one screen (FR-021). */
private fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
    context, 0, Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
)

/** One period of the prayer complication: from [start] to [end], showing [next]. */
data class PrayerSlot(val start: Long, val end: Long, val next: PrayerEntry?)

/** The periods of the timeline from [nowMs]: one per prayer, then "Open Mathani to update" after
 * the last time (research R2). Pure, for tests. */
fun prayerSlots(block: PrayerBlock, nowMs: Long): List<PrayerSlot> {
    if (block.isExpired(nowMs)) return listOf(PrayerSlot(nowMs, Long.MAX_VALUE, null))
    val slots = mutableListOf<PrayerSlot>()
    var start = nowMs
    for (entry in block.entries) {
        if (entry.atUtc <= nowMs) continue
        slots += PrayerSlot(start, entry.atUtc, entry)
        start = entry.atUtc
    }
    slots += PrayerSlot(start, Long.MAX_VALUE, null)
    return slots
}

/** The next prayer on the watch face, counting down (specs/017 User Story 4). */
class PrayerComplicationService : SuspendingTimelineComplicationDataSourceService() {
    override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationDataTimeline? {
        val copy = CopyStore(this).copy()
        val block = copy?.prayer ?: return ComplicationDataTimeline(NoDataComplicationData(), emptyList())
        val slots = prayerSlots(block, System.currentTimeMillis())
        fun data(slot: PrayerSlot) = build(request.complicationType, copy, slot.next)
        val first = slots.first()
        val entries = slots.drop(1).map { slot ->
            TimelineEntry(
                TimeInterval(Instant.ofEpochMilli(slot.start), if (slot.end == Long.MAX_VALUE) Instant.MAX else Instant.ofEpochMilli(slot.end)),
                data(slot),
            )
        }
        return ComplicationDataTimeline(data(first), entries)
    }

    private fun build(type: ComplicationType, copy: WatchCopy, next: PrayerEntry?): ComplicationData {
        if (next == null) {
            val message = text(copy.label("openToUpdate"))
            return when (type) {
                ComplicationType.LONG_TEXT -> LongTextComplicationData.Builder(message, message)
                    .setMonochromaticImage(icon(this)).setTapAction(openApp(this)).build()
                else -> ShortTextComplicationData.Builder(text("—"), message)
                    .setMonochromaticImage(icon(this)).setTapAction(openApp(this)).build()
            }
        }
        val countdown = TimeDifferenceComplicationText.Builder(
            TimeDifferenceStyle.SHORT_DUAL_UNIT,
            CountDownTimeReference(Instant.ofEpochMilli(next.atUtc)),
        ).build()
        val description = text(copy.label("a11yNext").replace("{name}", next.name).replace("{time}", next.time))
        return when (type) {
            ComplicationType.LONG_TEXT -> LongTextComplicationData.Builder(text("${next.name} ${next.time}"), description)
                .setTitle(countdown).setTapAction(openApp(this)).build()
            else -> ShortTextComplicationData.Builder(countdown, description)
                .setTitle(text(next.name)).setTapAction(openApp(this)).build()
        }
    }

    override fun getPreviewData(type: ComplicationType): ComplicationData? {
        val description = text(getString(R.string.complication_prayer))
        return when (type) {
            ComplicationType.LONG_TEXT -> LongTextComplicationData.Builder(text("Asr 3:12 PM"), description).build()
            ComplicationType.SHORT_TEXT -> ShortTextComplicationData.Builder(text("1h 5m"), description).setTitle(text("Asr")).build()
            else -> null
        }
    }
}

/** Khatma progress on the watch face (specs/017 User Story 5). */
class KhatmaComplicationService : SuspendingComplicationDataSourceService() {
    override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationData {
        val copy = CopyStore(this).copy()
        val k = copy?.khatma ?: return NoDataComplicationData()
        val description = text("${copy.label("khatma")}: ${k.text}")
        val label = text(if (k.todayRead) "✓" else "${k.percent}%")
        return when (request.complicationType) {
            ComplicationType.RANGED_VALUE -> RangedValueComplicationData.Builder(k.percent.toFloat(), 0f, 100f, description)
                .setText(label).setMonochromaticImage(icon(this)).setTapAction(openApp(this)).build()
            else -> ShortTextComplicationData.Builder(label, description)
                .setMonochromaticImage(icon(this)).setTapAction(openApp(this)).build()
        }
    }

    override fun getPreviewData(type: ComplicationType): ComplicationData? {
        val description = text(getString(R.string.complication_khatma))
        return when (type) {
            ComplicationType.RANGED_VALUE -> RangedValueComplicationData.Builder(41f, 0f, 100f, description).setText(text("41%")).build()
            ComplicationType.SHORT_TEXT -> ShortTextComplicationData.Builder(text("41%"), description).build()
            else -> null
        }
    }
}

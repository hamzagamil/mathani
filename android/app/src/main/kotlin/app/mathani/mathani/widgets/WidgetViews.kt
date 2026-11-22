package app.mathani.mathani.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import app.mathani.mathani.MainActivity
import app.mathani.mathani.R

/** What the prayer widget shows at a moment (pure, for tests). */
data class PrayerFrame(
    val next: PrayerEntry?,
    /** The day of [next]: at most five entries. */
    val day: List<PrayerEntry>,
    /** Row of [next] in [day], or -1. */
    val highlight: Int,
    val expired: Boolean,
)

fun prayerFrame(block: PrayerBlock, nowMs: Long): PrayerFrame {
    if (block.isExpired(nowMs)) return PrayerFrame(null, emptyList(), -1, true)
    val next = block.nextEntry(nowMs)
    val day = block.dayOf(next?.atUtc ?: nowMs).take(5)
    return PrayerFrame(next, day, day.indexOfFirst { it == next }, next == null)
}

/** When the widgets must be redrawn next: the next prayer, or the end of the times. */
fun nextRedrawAt(snapshot: Snapshot?, nowMs: Long): Long? {
    val block = snapshot?.prayer ?: return null
    if (block.isExpired(nowMs)) return null
    return block.nextEntry(nowMs)?.atUtc ?: block.validUntilUtc
}

/** Builds the RemoteViews of both widgets (specs/017 contracts/widget-surfaces.md). */
object WidgetViews {
    private const val MEDIUM_MIN_WIDTH_DP = 250

    /** A widget tap: the app opened on [link] (research R8). Distinct links get distinct
     * PendingIntents, so their data is never merged. */
    fun openIntent(context: Context, link: String): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(Intent.ACTION_VIEW)
            .setData(Uri.parse(link))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context, link.hashCode(), intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun message(context: Context, text: String?, link: String): RemoteViews =
        RemoteViews(context.packageName, R.layout.widget_message).apply {
            if (!text.isNullOrEmpty()) setTextViewText(R.id.message, text)
            setOnClickPendingIntent(R.id.widget_root, openIntent(context, link))
        }

    private fun RemoteViews.direction(rtl: Boolean) =
        setInt(R.id.widget_root, "setLayoutDirection", if (rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR)

    /** Small and medium layouts, chosen by the launcher (API 31+) or by width below. */
    private fun responsive(
        context: Context, options: Bundle?, small: () -> RemoteViews, medium: () -> RemoteViews,
    ): RemoteViews {
        if (Build.VERSION.SDK_INT >= 31) {
            return RemoteViews(mapOf(SizeF(110f, 110f) to small(), SizeF(MEDIUM_MIN_WIDTH_DP.toFloat(), 110f) to medium()))
        }
        val width = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
        return if (width >= MEDIUM_MIN_WIDTH_DP) medium() else small()
    }

    fun prayer(context: Context, snapshot: Snapshot?, options: Bundle?, nowMs: Long): RemoteViews {
        val link = "mathani-widget://prayer"
        val block = snapshot?.prayer
        if (snapshot == null) return message(context, null, link)
        if (block == null) return message(context, snapshot.label("setPlace"), link).apply { direction(snapshot.rtl) }
        val frame = prayerFrame(block, nowMs)
        val next = frame.next
        if (frame.expired || next == null) {
            return message(context, snapshot.label("openToUpdate"), link).apply { direction(snapshot.rtl) }
        }
        val base = SystemClock.elapsedRealtime() + (next.atUtc - System.currentTimeMillis())
        val a11y = snapshot.label("a11yNext").replace("{name}", next.name).replace("{time}", next.time)

        fun RemoteViews.common() {
            direction(snapshot.rtl)
            setTextViewText(R.id.place, block.place)
            setTextViewText(R.id.in_prefix, snapshot.label("inPrefix"))
            setTextViewText(R.id.in_suffix, snapshot.label("inSuffix"))
            setChronometerCountDown(R.id.countdown, true)
            setChronometer(R.id.countdown, base, null, true)
            setContentDescription(R.id.widget_root, a11y)
            setOnClickPendingIntent(R.id.widget_root, openIntent(context, link))
        }

        val small = {
            RemoteViews(context.packageName, R.layout.widget_prayer_small).apply {
                common()
                setTextViewText(R.id.next_label, snapshot.label("next"))
                setTextViewText(R.id.name, next.name)
                setTextViewText(R.id.time, next.time)
            }
        }
        val medium = {
            RemoteViews(context.packageName, R.layout.widget_prayer_medium).apply {
                common()
                for (i in 0 until 5) {
                    val row = ROWS[i]
                    val entry = frame.day.getOrNull(i)
                    if (entry == null) {
                        setViewVisibility(row.root, View.GONE)
                        continue
                    }
                    setViewVisibility(row.root, View.VISIBLE)
                    setTextViewText(row.name, entry.name)
                    setTextViewText(row.time, entry.time)
                    setInt(row.root, "setBackgroundResource", if (i == frame.highlight) R.drawable.widget_row_highlight else 0)
                }
            }
        }
        return responsive(context, options, small, medium)
    }

    fun quran(context: Context, snapshot: Snapshot?, options: Bundle?): RemoteViews {
        val block = snapshot?.quran ?: return message(context, null, "mathani-widget://mushaf/1")

        fun RemoteViews.common() {
            direction(snapshot.rtl)
            setTextViewText(R.id.title, block.title)
            setTextViewText(R.id.line1, block.line1)
            setTextViewText(R.id.line2, block.line2)
            setViewVisibility(R.id.line1, if (block.line1.isEmpty()) View.GONE else View.VISIBLE)
            setViewVisibility(R.id.line2, if (block.line2.isEmpty()) View.GONE else View.VISIBLE)
            setViewVisibility(R.id.check, if (block.mode == "wirdDone") View.VISIBLE else View.GONE)
            setContentDescription(R.id.widget_root, listOf(block.title, block.line1, block.line2)
                .filter { it.isNotEmpty() }.joinToString(", "))
            setOnClickPendingIntent(R.id.widget_root, openIntent(context, block.link))
        }

        val small = { RemoteViews(context.packageName, R.layout.widget_quran_small).apply { common() } }
        val medium = {
            RemoteViews(context.packageName, R.layout.widget_quran_medium).apply {
                common()
                val p = block.progress
                val shown = if (p == null) View.GONE else View.VISIBLE
                setViewVisibility(R.id.progress, shown)
                setViewVisibility(R.id.progress_text, shown)
                if (p != null) {
                    setProgressBar(R.id.progress, 100, p.percent, false)
                    setTextViewText(R.id.progress_text, p.text)
                }
            }
        }
        return responsive(context, options, small, medium)
    }

    private data class Row(val root: Int, val name: Int, val time: Int)

    private val ROWS = listOf(
        Row(R.id.row0, R.id.row0_name, R.id.row0_time),
        Row(R.id.row1, R.id.row1_name, R.id.row1_time),
        Row(R.id.row2, R.id.row2_name, R.id.row2_time),
        Row(R.id.row3, R.id.row3_name, R.id.row3_time),
        Row(R.id.row4, R.id.row4_name, R.id.row4_time),
    )
}

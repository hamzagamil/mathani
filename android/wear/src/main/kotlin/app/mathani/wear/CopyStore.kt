package app.mathani.wear

import android.content.Context
import org.json.JSONObject

/** One prayer time from the phone (specs/017 data-model.md › PrayerEntry). */
data class PrayerEntry(val kind: String, val atUtc: Long, val name: String, val time: String)

data class WidgetDay(val startUtc: Long, val label: String)

data class PrayerBlock(
    val place: String,
    val entries: List<PrayerEntry>,
    val days: List<WidgetDay>,
    val validUntilUtc: Long,
) {
    /** The first entry after [nowMs]: the one rule every platform uses. */
    fun nextEntry(nowMs: Long): PrayerEntry? = entries.firstOrNull { it.atUtc > nowMs }

    fun previousOf(entry: PrayerEntry): PrayerEntry? = entries.indexOf(entry).takeIf { it > 0 }?.let { entries[it - 1] }

    fun isExpired(nowMs: Long) = nowMs >= validUntilUtc

    /** The place's day containing [moment]: its label and prayers (at most five). */
    fun dayOf(moment: Long): Pair<String, List<PrayerEntry>> {
        val start = days.lastOrNull { it.startUtc <= moment } ?: return "" to emptyList()
        val end = days.firstOrNull { it.startUtc > start.startUtc }?.startUtc ?: Long.MAX_VALUE
        return start.label to entries.filter { it.atUtc in start.startUtc until end }.take(5)
    }
}

data class KhatmaProgress(val percent: Int, val todayRead: Boolean, val paused: Boolean, val text: String)

/** The watch copy (specs/017 data-model.md › WatchCopy): prayer times and khatma progress. */
data class WatchCopy(
    val madeAtUtc: Long,
    val lang: String,
    val rtl: Boolean,
    val labels: Map<String, String>,
    val prayer: PrayerBlock?,
    val khatma: KhatmaProgress?,
) {
    fun label(key: String) = labels[key] ?: ""

    companion object {
        /** Null for a newer version, broken JSON or times out of order. */
        fun parse(json: String?): WatchCopy? {
            if (json.isNullOrEmpty()) return null
            return try {
                val o = JSONObject(json)
                if (o.optInt("v", 0) != 1) return null
                val labels = mutableMapOf<String, String>()
                o.optJSONObject("labels")?.let { l -> l.keys().forEach { labels[it] = l.optString(it) } }
                WatchCopy(
                    madeAtUtc = o.getLong("madeAtUtc"),
                    lang = o.optString("lang", "en"),
                    rtl = o.optBoolean("rtl", false),
                    labels = labels,
                    prayer = o.optJSONObject("prayer")?.let(::prayer),
                    khatma = o.optJSONObject("khatma")?.let {
                        KhatmaProgress(it.getInt("percent").coerceIn(0, 100), it.optBoolean("todayRead"),
                            it.optBoolean("paused"), it.optString("text"))
                    },
                )
            } catch (e: Exception) {
                null
            }
        }

        private fun prayer(o: JSONObject): PrayerBlock {
            val raw = o.getJSONArray("entries")
            val entries = List(raw.length()) {
                val e = raw.getJSONObject(it)
                PrayerEntry(e.getString("kind"), e.getLong("atUtc"), e.getString("name"), e.getString("time"))
            }
            require(entries.isNotEmpty() && entries.zipWithNext().all { (a, b) -> b.atUtc > a.atUtc })
            val rawDays = o.optJSONArray("days")
            val days = if (rawDays == null) emptyList() else List(rawDays.length()) {
                val d = rawDays.getJSONObject(it)
                WidgetDay(d.getLong("startUtc"), d.getString("label"))
            }
            return PrayerBlock(o.getString("place"), entries, days, o.getLong("validUntilUtc"))
        }
    }
}

/** Where the watch keeps the newest copy (contracts/watch-sync.md). */
class CopyStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("mathani_watch_copy", Context.MODE_PRIVATE)

    fun json(): String? = prefs.getString("copy", null)

    fun copy(): WatchCopy? = WatchCopy.parse(json())

    /** Keeps [json] if it is newer than the stored copy; true when it was kept. */
    fun offer(json: String): Boolean = synchronized(lock) {
        val incoming = WatchCopy.parse(json) ?: return false
        if (!isNewer(incoming, copy())) return false
        prefs.edit().putString("copy", json).apply()
        true
    }

    companion object {
        private val lock = Any()
        fun isNewer(incoming: WatchCopy, current: WatchCopy?) = current == null || incoming.madeAtUtc > current.madeAtUtc
    }
}

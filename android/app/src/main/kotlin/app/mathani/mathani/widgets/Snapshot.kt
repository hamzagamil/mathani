package app.mathani.mathani.widgets

import org.json.JSONObject

/** One prayer time, as Dart built it (specs/017 data-model.md › PrayerEntry). */
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

    fun isExpired(nowMs: Long) = nowMs >= validUntilUtc

    /** The entries of the place's day that contains [nowMs] (at most five). */
    fun dayOf(nowMs: Long): List<PrayerEntry> {
        val start = days.lastOrNull { it.startUtc <= nowMs }?.startUtc ?: return emptyList()
        val end = days.firstOrNull { it.startUtc > start }?.startUtc ?: Long.MAX_VALUE
        return entries.filter { it.atUtc in start until end }
    }
}

data class KhatmaProgress(
    val percent: Int, val pagesRead: Int, val pagesTotal: Int, val text: String,
    val todayRead: Boolean, val paused: Boolean,
)

data class QuranBlock(
    val mode: String, val title: String, val line1: String, val line2: String,
    val progress: KhatmaProgress?, val link: String,
)

/** The widget snapshot (specs/017 contracts/widget-snapshot.md). */
data class Snapshot(
    val madeAtUtc: Long,
    val lang: String,
    val rtl: Boolean,
    val labels: Map<String, String>,
    val prayer: PrayerBlock?,
    val quran: QuranBlock?,
) {
    fun label(key: String) = labels[key] ?: ""

    companion object {
        const val VERSION = 1

        /** Null when [json] is missing, of a newer version, or broken: widgets then show the
         * "not set up" state rather than wrong times. */
        fun parse(json: String?): Snapshot? {
            if (json.isNullOrEmpty()) return null
            return try {
                val o = JSONObject(json)
                if (o.optInt("v", 0) != VERSION) return null
                val labels = mutableMapOf<String, String>()
                o.optJSONObject("labels")?.let { l -> l.keys().forEach { labels[it] = l.optString(it) } }
                Snapshot(
                    madeAtUtc = o.getLong("madeAtUtc"),
                    lang = o.optString("lang", "en"),
                    rtl = o.optBoolean("rtl", false),
                    labels = labels,
                    prayer = o.optJSONObject("prayer")?.let(::prayer),
                    quran = o.optJSONObject("quran")?.let(::quran),
                )
            } catch (e: Exception) {
                null
            }
        }

        private fun prayer(o: JSONObject): PrayerBlock? {
            val raw = o.getJSONArray("entries")
            val entries = List(raw.length()) {
                val e = raw.getJSONObject(it)
                PrayerEntry(e.getString("kind"), e.getLong("atUtc"), e.getString("name"), e.getString("time"))
            }
            // Ascending with unique instants, or nothing (contracts/widget-snapshot.md › Validation).
            if (entries.isEmpty() || entries.zipWithNext().any { (a, b) -> b.atUtc <= a.atUtc }) {
                throw IllegalArgumentException("entries out of order")
            }
            val rawDays = o.optJSONArray("days")
            val days = if (rawDays == null) emptyList() else List(rawDays.length()) {
                val d = rawDays.getJSONObject(it)
                WidgetDay(d.getLong("startUtc"), d.getString("label"))
            }
            return PrayerBlock(o.getString("place"), entries, days, o.getLong("validUntilUtc"))
        }

        private fun quran(o: JSONObject): QuranBlock {
            val p = o.optJSONObject("progress")
            return QuranBlock(
                mode = o.getString("mode"),
                title = o.optString("title"),
                line1 = o.optString("line1"),
                line2 = o.optString("line2"),
                progress = p?.let {
                    KhatmaProgress(
                        it.getInt("percent").coerceIn(0, 100), it.optInt("pagesRead"), it.optInt("pagesTotal"),
                        it.optString("text"), it.optBoolean("todayRead"), it.optBoolean("paused"),
                    )
                },
                link = o.getString("link"),
            )
        }
    }
}

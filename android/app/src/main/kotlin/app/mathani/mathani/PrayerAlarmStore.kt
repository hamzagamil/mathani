package app.mathani.mathani

import android.content.Context
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream

/** One pending prayer alert, as Dart built it (specs/009 data-model.md › Alert). */
data class PrayerAlert(
    val id: Int, val kind: String, val atUtcMs: Long, val title: String, val body: String,
    val sound: String, val full: Boolean = false, val fullPath: String? = null,
) {
    init {
        require(id >= 0 && atUtcMs > 0)
        require(kind in setOf("fajr", "dhuhr", "asr", "maghrib", "isha", "qiyam"))
        require(Regex("[a-z0-9_]{1,64}").matches(sound))
        require(title.length in 1..160 && body.length <= 512)
    }
}

/** Where the list is kept: SharedPreferences in the app, memory in tests. */
interface PrayerStoreBackend {
    fun read(): String?
    fun write(value: String)
}

private class PreferencesBackend(context: Context) : PrayerStoreBackend {
    private val prefs = context.applicationContext.getSharedPreferences("mathani_prayer_alerts", Context.MODE_PRIVATE)
    override fun read(): String? = prefs.getString("alerts", null)
    override fun write(value: String) { check(prefs.edit().putString("alerts", value).commit()) }
}

/** The alerts Dart scheduled, so the receiver can post them and reboots can restore them without
 * starting Flutter. A derived copy: every refill from the app replaces it (research R7). */
class PrayerAlarmStore(private val backend: PrayerStoreBackend) {
    constructor(context: Context) : this(PreferencesBackend(context))
    companion object { private val lock = Any(); const val MAX = 64 }
    private data class Snapshot(val generation: Long, val alerts: List<PrayerAlert>)

    private fun load(): Snapshot {
        val hex = backend.read() ?: return Snapshot(0, emptyList())
        val bytes = ByteArray(hex.length / 2) { hex.substring(it * 2, it * 2 + 2).toInt(16).toByte() }
        DataInputStream(ByteArrayInputStream(bytes)).use { input ->
            if (input.readInt() != 2) return Snapshot(0, emptyList())
            val generation = input.readLong()
            val alerts = List(input.readInt()) {
                PrayerAlert(input.readInt(), input.readUTF(), input.readLong(), input.readUTF(), input.readUTF(),
                    input.readUTF(), input.readBoolean(), input.readUTF().ifEmpty { null })
            }
            return Snapshot(generation, alerts)
        }
    }

    private fun save(snapshot: Snapshot) {
        val bytes = ByteArrayOutputStream()
        DataOutputStream(bytes).use { out ->
            out.writeInt(2); out.writeLong(snapshot.generation); out.writeInt(snapshot.alerts.size)
            snapshot.alerts.forEach {
                out.writeInt(it.id); out.writeUTF(it.kind); out.writeLong(it.atUtcMs); out.writeUTF(it.title)
                out.writeUTF(it.body); out.writeUTF(it.sound); out.writeBoolean(it.full); out.writeUTF(it.fullPath ?: "")
            }
        }
        backend.write(bytes.toByteArray().joinToString("") { "%02x".format(it) })
    }

    fun generation(): Long = synchronized(lock) { load().generation }

    /** Replaces the whole list; returns the ids that are no longer pending. */
    fun replace(generation: Long, alerts: List<PrayerAlert>): Set<Int> = synchronized(lock) {
        require(alerts.size <= MAX && alerts.map { it.id }.toSet().size == alerts.size)
        val old = load().alerts.map { it.id }.toSet()
        save(Snapshot(generation, alerts))
        old - alerts.map { it.id }.toSet()
    }

    fun get(id: Int): PrayerAlert? = synchronized(lock) { load().alerts.find { it.id == id } }

    /** Removes [id] and reports whether it was still pending, so an alert is posted once. */
    fun remove(id: Int): Boolean = synchronized(lock) {
        val s = load()
        if (s.alerts.none { it.id == id }) return false
        save(s.copy(alerts = s.alerts.filter { it.id != id }))
        true
    }

    fun future(nowMs: Long): List<PrayerAlert> = synchronized(lock) {
        load().alerts.filter { it.atUtcMs > nowMs }.sortedBy { it.atUtcMs }
    }

    fun all(): List<PrayerAlert> = synchronized(lock) { load().alerts }

    fun clear(): Set<Int> = replace(generation(), emptyList())
}

/** What the receiver does with a due alert (contracts › Android). Pure, for JVM tests. */
enum class AlertAction { IGNORE, DROP, POST, PLAY_FULL }

object PrayerAlertRules {
    /** Alerts later than this are missed, not delivered (FR-022). */
    const val LATENESS_MS = 15 * 60_000L

    fun decide(
        alert: PrayerAlert?, alertGeneration: Long, storedGeneration: Long, nowMs: Long,
        fullFileExists: Boolean, canStartFull: Boolean,
    ): AlertAction = when {
        alert == null || alertGeneration != storedGeneration -> AlertAction.IGNORE
        nowMs - alert.atUtcMs > LATENESS_MS -> AlertAction.DROP
        alert.full && alert.kind != "qiyam" && fullFileExists && canStartFull -> AlertAction.PLAY_FULL
        else -> AlertAction.POST
    }
}

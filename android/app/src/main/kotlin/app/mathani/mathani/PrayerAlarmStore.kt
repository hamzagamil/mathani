package app.mathani.mathani

import android.content.Context
import android.os.UserManager
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Only the event token/generation belongs in an alarm Intent. This presentation
 * data stays in the protected, replaceable queue, never plugin preferences. */
data class PrayerAlarmEvent(
    val eventId: String, val locationId: String, val generation: Long,
    val dueAtMs: Long, val expiresAtMs: Long, val kind: String,
    val assetId: String, val mode: String, val title: String, val body: String,
    val state: String = "pending", val owner: String? = null, val consumed: Boolean = false,
    val startedAtMs: Long? = null,
) {
    init {
        require(Regex("[A-Za-z0-9_-]{1,160}").matches(eventId))
        // Saved locations created by base64UrlEncode retain optional padding.
        // Keep those stable IDs usable without rewriting encrypted snapshots.
        require(locationId.length <= 160 && Regex("[A-Za-z0-9_-]+={0,2}").matches(locationId))
        require(generation >= 0 && dueAtMs > 0 && expiresAtMs >= dueAtMs && expiresAtMs - dueAtMs <= 60_000)
        require(kind in setOf("fajr", "dhuhr", "asr", "maghrib", "isha", "qiyam"))
        require(Regex("[a-z][a-z0-9_]{0,63}").matches(assetId))
        require(mode in setOf("full", "opening") && (kind != "qiyam" || mode == "opening"))
        require(title.length in 1..160 && body.length <= 512)
        require(state in setOf("pending", "claimed", "playing", "delivered", "cancelled", "failed"))
        require(owner == null || owner in setOf("appAudio", "systemFallback"))
    }
}

/** Reads/writes plaintext only across an in-process boundary. Implementations
 * must encrypt at rest and throw on unreadable data; null means absent only. */
interface PrayerQueueBackend {
    fun read(): ByteArray?
    fun write(value: ByteArray)
}

class PrayerQueueCipher(private val key: () -> SecretKey) {
    private val aad = "com.mthani.app/prayer-alarm-queue/v1".toByteArray(Charsets.UTF_8)
    fun encrypt(plain: ByteArray): ByteArray {
        require(plain.size <= 1_048_576)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        cipher.updateAAD(aad)
        require(cipher.iv.size == 12)
        return byteArrayOf(1) + cipher.iv + cipher.doFinal(plain)
    }
    fun decrypt(envelope: ByteArray): ByteArray {
        require(envelope.size in 30..1_048_605 && envelope[0].toInt() == 1)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, envelope.copyOfRange(1, 13)))
        cipher.updateAAD(aad)
        return cipher.doFinal(envelope.copyOfRange(13, envelope.size))
    }
}

private class AndroidPrayerQueueBackend(context: Context) : PrayerQueueBackend {
    private val context = context.applicationContext
    private val file = AtomicFile(File(this.context.filesDir, "prayer/alarm-queue.v1"))
    private val cipher = PrayerQueueCipher { key() }
    private fun checkUnlocked() {
        check(context.getSystemService(UserManager::class.java)?.isUserUnlocked == true) { "Prayer store unavailable before first unlock" }
    }
    private fun key(): SecretKey {
        val keystore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val alias = "mathani.prayer.alarm.v1"
        if (keystore.containsAlias(alias)) {
            return (keystore.getEntry(alias, null) as KeyStore.SecretKeyEntry).secretKey
        }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setKeySize(256).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setUserAuthenticationRequired(false).setRandomizedEncryptionRequired(true).build())
        }.generateKey()
    }
    override fun read(): ByteArray? {
        checkUnlocked()
        if (!file.baseFile.exists() && !File(file.baseFile.path + ".bak").exists()) return null
        return cipher.decrypt(file.readFully())
    }
    override fun write(value: ByteArray) {
        checkUnlocked()
        val encrypted = cipher.encrypt(value)
        check(file.baseFile.parentFile!!.isDirectory || file.baseFile.parentFile!!.mkdirs())
        val output = file.startWrite()
        try { output.write(encrypted); file.finishWrite(output) }
        catch (error: Exception) { file.failWrite(output); throw error }
    }
}

/** All instances share a lock and re-read inside each transaction. The receiver
 * and Flutter bridge run in the app's default process; no extra process exists. */
class PrayerAlarmStore(private val backend: PrayerQueueBackend) {
    constructor(context: Context) : this(AndroidPrayerQueueBackend(context))
    companion object { private val lock = Any(); private const val MAX_EVENTS = 192 }
    private data class Snapshot(val generation: Long, val events: List<PrayerAlarmEvent>)

    private fun load(): Snapshot {
        val bytes = backend.read() ?: return Snapshot(0, emptyList())
        require(bytes.size <= 1_048_576)
        DataInputStream(ByteArrayInputStream(bytes)).use { input ->
            require(input.readInt() == 1) { "Unsupported prayer queue version" }
            val generation = input.readLong(); require(generation >= 0)
            val count = input.readInt(); require(count in 0..MAX_EVENTS)
            val events = List(count) {
                PrayerAlarmEvent(input.readUTF(), input.readUTF(), input.readLong(), input.readLong(), input.readLong(),
                    input.readUTF(), input.readUTF(), input.readUTF(), input.readUTF(), input.readUTF(),
                    input.readUTF(), input.readUTF().ifEmpty { null }, input.readBoolean(), input.readLong().takeIf { it >= 0 })
            }
            require(events.all { it.generation == generation } && events.map { it.eventId }.toSet().size == count)
            require(input.available() == 0)
            return Snapshot(generation, events)
        }
    }
    private fun save(snapshot: Snapshot) {
        val bytes = ByteArrayOutputStream()
        DataOutputStream(bytes).use { output ->
            output.writeInt(1); output.writeLong(snapshot.generation); output.writeInt(snapshot.events.size)
            snapshot.events.forEach { event ->
                output.writeUTF(event.eventId); output.writeUTF(event.locationId); output.writeLong(event.generation)
                output.writeLong(event.dueAtMs); output.writeLong(event.expiresAtMs); output.writeUTF(event.kind)
                output.writeUTF(event.assetId); output.writeUTF(event.mode); output.writeUTF(event.title); output.writeUTF(event.body)
                output.writeUTF(event.state); output.writeUTF(event.owner ?: ""); output.writeBoolean(event.consumed); output.writeLong(event.startedAtMs ?: -1)
            }
        }
        backend.write(bytes.toByteArray())
    }
    fun generation(): Long = synchronized(lock) { load().generation }
    fun clearPending() = synchronized(lock) { save(Snapshot(load().generation, emptyList())) }
    fun replace(generation: Long, events: List<PrayerAlarmEvent>, nowMs: Long) = synchronized(lock) {
        val previous = load()
        require(generation >= previous.generation && events.size <= MAX_EVENTS)
        require(events.map { it.eventId }.toSet().size == events.size)
        require(events.all { it.generation == generation && it.dueAtMs > nowMs &&
            it.dueAtMs - nowMs <= 30L * 24 * 60 * 60 * 1000 && it.state == "pending" && !it.consumed && it.owner == null })
        val old = previous.events.associateBy { it.eventId }
        val merged = events.map { event ->
            val existing = old[event.eventId]?.takeIf { generation == previous.generation }
            if (existing != null) {
                require(existing.copy(state = "pending", owner = null, consumed = false, startedAtMs = null) == event) { "Event identity changed within generation" }
                existing
            } else event
        }
        save(Snapshot(generation, merged))
    }
    fun future(nowMs: Long): List<PrayerAlarmEvent> = synchronized(lock) {
        load().events.filter { it.state == "pending" && !it.consumed && it.dueAtMs > nowMs }.sortedBy { it.dueAtMs }
    }
    fun event(eventId: String, generation: Long): PrayerAlarmEvent? = synchronized(lock) {
        load().takeIf { it.generation == generation }?.events?.find { it.eventId == eventId }
    }
    private fun change(eventId: String, generation: Long, update: (PrayerAlarmEvent) -> PrayerAlarmEvent?): Boolean = synchronized(lock) {
        val snapshot = load()
        if (snapshot.generation != generation) return false
        val event = snapshot.events.find { it.eventId == eventId } ?: return false
        val changed = update(event) ?: return false
        save(snapshot.copy(events = snapshot.events.map { if (it.eventId == eventId) changed else it }))
        true
    }
    private fun due(event: PrayerAlarmEvent, nowMs: Long) = nowMs >= event.dueAtMs && nowMs <= event.expiresAtMs && !event.consumed
    fun claimAudio(eventId: String, generation: Long, nowMs: Long): Boolean = change(eventId, generation) {
        if (due(it, nowMs) && it.state == "pending") it.copy(state = "claimed", owner = "appAudio") else null
    }
    fun markStarted(eventId: String, generation: Long, nowMs: Long): Boolean = change(eventId, generation) {
        if (due(it, nowMs) && it.state == "claimed" && it.owner == "appAudio") it.copy(state = "playing", consumed = true, startedAtMs = nowMs) else null
    }
    fun claimFallback(eventId: String, generation: Long, nowMs: Long): Boolean = change(eventId, generation) {
        if (due(it, nowMs) && (it.state == "pending" || (it.state == "claimed" && it.owner == "appAudio")))
            it.copy(state = "delivered", owner = "systemFallback", consumed = true) else null
    }
    /** Keep source invalidation/cancellation ordered after the OS post, rather
     * than letting an already-claimed receiver post after cancelAll returned. */
    fun deliverFallback(eventId: String, generation: Long, nowMs: Long, deliver: () -> Unit): Boolean = synchronized(lock) {
        if (!claimFallback(eventId, generation, nowMs)) return false
        deliver()
        true
    }
    fun cancel(eventId: String, generation: Long): Boolean = change(eventId, generation) { it.copy(state = "cancelled", consumed = true) }
    fun finish(eventId: String, generation: Long): Boolean = change(eventId, generation) {
        if (it.state == "playing" && it.owner == "appAudio" && it.consumed) it.copy(state = "delivered") else null
    }
    fun cancelAll(newGeneration: Long) = synchronized(lock) {
        require(newGeneration > load().generation)
        save(Snapshot(newGeneration, emptyList()))
    }
}

package app.mathani.mathani.widgets

import android.content.Context
import java.security.MessageDigest

/** Where the snapshot is kept: SharedPreferences in the app, memory in tests. */
interface SnapshotBackend {
    fun read(key: String): String?
    fun write(values: Map<String, String?>)
}

private class PreferencesSnapshotBackend(context: Context) : SnapshotBackend {
    private val prefs = context.applicationContext.getSharedPreferences(SnapshotStore.FILE, Context.MODE_PRIVATE)
    override fun read(key: String): String? = prefs.getString(key, null)
    override fun write(values: Map<String, String?>) {
        val edit = prefs.edit()
        values.forEach { (k, v) -> if (v == null) edit.remove(k) else edit.putString(k, v) }
        edit.apply()
    }
}

/** The latest widget snapshot from Dart (specs/017 contracts/widget-snapshot.md › Storage). A
 * derived copy: every update from the app replaces it. */
class SnapshotStore(private val backend: SnapshotBackend) {
    constructor(context: Context) : this(PreferencesSnapshotBackend(context))

    companion object {
        const val FILE = "mathani_widget_snapshot"
        private val lock = Any()

        fun sha256(text: String): String =
            MessageDigest.getInstance("SHA-256").digest(text.toByteArray()).joinToString("") { "%02x".format(it) }
    }

    fun json(): String? = synchronized(lock) { backend.read("snapshot") }

    fun snapshot(): Snapshot? = Snapshot.parse(json())

    /** Stores [json]; true when it differs from the stored one, so widgets need a redraw. */
    fun put(json: String): Boolean = synchronized(lock) {
        val hash = sha256(json)
        if (backend.read("hash") == hash) return false
        backend.write(mapOf("snapshot" to json, "hash" to hash))
        true
    }

    fun clear() = synchronized(lock) { backend.write(mapOf("snapshot" to null, "hash" to null)) }
}

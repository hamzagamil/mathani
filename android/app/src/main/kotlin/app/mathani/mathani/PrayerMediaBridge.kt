package app.mathani.mathani

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.session.MediaControllerCompat
import com.ryanheise.audioservice.AudioService
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/** G01 prototype only. The receiver/permission/tone exist in src/debug and Dart
 * requires PRAYER_ALARM_SPIKE=true. No production scheduled-full capability is enabled. */
object PrayerMediaBridge {
    const val ROUTE = "/prayer-alarm-spike"
    private const val CHANNEL = "app.mathani/prayer_alarm_spike"
    private val handler = Handler(Looper.getMainLooper())
    private var ready = false
    private val connections = mutableMapOf<String, Connection>()
    private fun debug(context: Context) = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

    fun register(engine: FlutterEngine, context: Context) {
        if (!debug(context)) return
        val app = context.applicationContext
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            try {
                val store = PrayerAlarmStore(app)
                val id = call.argument<String>("eventId")
                val generation = call.argument<Number>("generation")?.toLong()
                when (call.method) {
                    "ready" -> { ready = true; connections.values.toList().forEach { it.dispatch() }; result.success(null) }
                    "capabilities" -> {
                        val alarms = app.getSystemService(AlarmManager::class.java)
                        result.success(mapOf("exactAlarmAccess" to (Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()),
                            "notificationsGranted" to (Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(app, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)))
                    }
                    "schedule" -> {
                        val delay = call.argument<Number>("delayMs")?.toLong() ?: 20_000
                        require(delay in 5_000..300_000)
                        val alarms = app.getSystemService(AlarmManager::class.java)
                        check(Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()) { "exactAlarmDenied" }
                        val next = store.generation() + 1
                        val token = UUID.randomUUID().toString()
                        val now = System.currentTimeMillis()
                        store.replace(next, listOf(PrayerAlarmEvent(token, "spike_location", next, now + delay,
                            now + delay + 60_000, "fajr", "prayer_spike_tone", "opening", "Prayer startup test", "Generated test tone")), now)
                        val intent = Intent().setClassName(app, "app.mathani.mathani.PrayerAlarmSpikeReceiver")
                            .setAction("app.mathani.PRAYER_SPIKE.$token").putExtra("eventId", token).putExtra("generation", next)
                        val pending = PendingIntent.getBroadcast(app, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                        alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, now + delay, pending)
                        result.success(mapOf("eventId" to token, "generation" to next, "dueAtMs" to now + delay))
                    }
                    "source" -> {
                        require(id != null && generation != null)
                        val event = store.event(id, generation)
                        val now = System.currentTimeMillis()
                        val resource = app.resources.getIdentifier("prayer_spike_tone", "raw", app.packageName)
                        if (event == null || event.state != "claimed" || event.owner != "appAudio" || event.consumed ||
                            now < event.dueAtMs || now > event.expiresAtMs || resource == 0) result.success(null)
                        else result.success("android.resource://${app.packageName}/$resource")
                    }
                    "claimStart" -> {
                        require(id != null && generation != null)
                        result.success(store.markStarted(id, generation, System.currentTimeMillis()))
                    }
                    "ackStarted" -> {
                        require(id != null && generation != null)
                        val event = store.event(id, generation)
                        val started = event?.state == "playing" && event.owner == "appAudio" && event.consumed
                        if (started) connections.remove(id)?.finish(true)
                        result.success(started)
                    }
                    "finish" -> { require(id != null && generation != null); result.success(store.finish(id, generation)) }
                    "cancel" -> { require(id != null && generation != null); result.success(store.cancel(id, generation)); connections.remove(id)?.finish(false) }
                    "stop" -> {
                        require(id != null && generation != null)
                        check(store.cancel(id, generation))
                        connections.remove(id)?.finish(false)
                        channel.invokeMethod("stopFromNative", null, object : MethodChannel.Result {
                            override fun success(value: Any?) { result.success(value) }
                            override fun error(code: String, message: String?, details: Any?) { result.error("stopUnconfirmed", "Audio stop was not acknowledged", null) }
                            override fun notImplemented() { result.error("stopUnconfirmed", "Audio stop was not acknowledged", null) }
                        })
                    }
                    "inspect" -> {
                        require(id != null && generation != null)
                        val event = store.event(id, generation)
                        result.success(event?.let { mapOf("eventId" to it.eventId, "generation" to it.generation,
                            "dueAtMs" to it.dueAtMs, "state" to it.state, "owner" to it.owner,
                            "consumed" to it.consumed, "startedAtMs" to it.startedAtMs,
                            "engineId" to System.identityHashCode(FlutterEngineCache.getInstance().get(AudioServicePlugin.getFlutterEngineId()))) })
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                // Never return encrypted queue presentation or exception/provider details.
                result.error("spikeUnavailable", "Prayer startup test is unavailable; check grants and unlocked storage", null)
            }
        }
    }

    /** Shares audio_service's actual cache key; never creates a second player service. */
    private fun engine(context: Context): FlutterEngine {
        val key = AudioServicePlugin.getFlutterEngineId()
        FlutterEngineCache.getInstance().get(key)?.let { return it }
        val created = FlutterEngine(context.applicationContext)
        register(created, context)
        FlutterEngineCache.getInstance().put(key, created)
        created.navigationChannel.setInitialRoute(ROUTE)
        created.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        return created
    }

    fun deliver(context: Context, eventId: String, generation: Long, complete: (Boolean) -> Unit) {
        if (!debug(context)) { complete(false); return }
        try {
            val app = context.applicationContext
            if (!PrayerAlarmStore(app).claimAudio(eventId, generation, System.currentTimeMillis())) { complete(false); return }
            engine(app)
            val connection = Connection(app, eventId, generation, complete)
            connections[eventId] = connection
            connection.connect()
            handler.postDelayed({ if (connections.remove(eventId) === connection) connection.finish(false) }, 8_000)
        } catch (error: Exception) { complete(false) }
    }

    private class Connection(val context: Context, val eventId: String, val generation: Long, val complete: (Boolean) -> Unit) : MediaBrowserCompat.ConnectionCallback() {
        private val browser = MediaBrowserCompat(context, ComponentName(context, AudioService::class.java), this, null)
        private var controller: MediaControllerCompat? = null
        private var sent = false
        private var finished = false
        fun connect() { browser.connect() }
        override fun onConnected() { controller = MediaControllerCompat(context, browser.sessionToken); dispatch() }
        override fun onConnectionFailed() { finish(false) }
        override fun onConnectionSuspended() { finish(false) }
        fun dispatch() {
            if (!ready || controller == null || sent || finished) return
            sent = true
            controller!!.transportControls.sendCustomAction("prayerSpike", Bundle().apply { putString("eventId", eventId); putLong("generation", generation) })
        }
        fun finish(started: Boolean) {
            if (finished) return
            finished = true
            browser.disconnect()
            complete(started)
        }
    }
}

package app.mathani.mathani

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/** Prayer alerts on Android (specs/009 contracts/prayer-ui-and-reminders.md › Native contract):
 * one alarm per alert from the app's own store, a channel per sound, and the athan service. */
class PrayerNotificationsPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var permissionResult: MethodChannel.Result? = null

    companion object {
        const val OPEN_ACTION = "app.mathani.OPEN_PRAYER"
        const val ALERT_ACTION = "app.mathani.PRAYER_ALERT"
        const val QIYAM_CHANNEL = "prayer_qiyam_v2"
        const val PLAYBACK_CHANNEL = "prayer_athan_playback_v1"
        const val REMINDER_ACTION = "app.mathani.KHATMA_REMINDER"
        const val REMINDER_CHANNEL = "khatma_reminder_v1"
        const val REMINDER_TAG = "mathani.khatma"
        /** Announcements from the Firebase console (specs/015 R8); also the manifest default. */
        const val ANNOUNCEMENT_CHANNEL = "announcements_v1"
        const val ANNOUNCEMENT_TAG = "mathani.announcement"
        private const val PERMISSION_REQUEST = 7413
        private const val PREFS = "mathani_prayer_settings"
        private var pendingOpen: Map<String, Any?>? = null
        private var events: MethodChannel? = null

        fun register(engine: FlutterEngine) {
            if (!engine.plugins.has(PrayerNotificationsPlugin::class.java)) engine.plugins.add(PrayerNotificationsPlugin())
        }

        /** MainActivity hands over the intent it was opened with. */
        fun noteOpenIntent(intent: Intent?) {
            if (intent?.action != OPEN_ACTION) return
            val opened = mapOf("kind" to intent.getStringExtra("kind"), "alertId" to intent.getIntExtra("id", -1),
                "link" to intent.getStringExtra("link"))
            pendingOpen = opened
            events?.invokeMethod("opened", opened)
        }

        fun emit(method: String) { events?.invokeMethod(method, null) }

        fun exact(context: Context) =
            Build.VERSION.SDK_INT < 31 || context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

        fun granted(context: Context) = NotificationManagerCompat.from(context).areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 33 ||
                ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)

        fun soundChannel(alert: PrayerAlert) =
            if (PrayerAlertRules.isReminder(alert.kind)) QIYAM_CHANNEL else channelId(alert.sound)

        /** v2 for the tone: its sound became the takbira, and a channel's sound is fixed once created. */
        fun channelId(sound: String) = if (sound == "tone") "prayer_tone_v2" else "prayer_${sound}_v1"

        fun soundUri(context: Context, sound: String): Uri? {
            val name = if (sound == "tone") "athan_takbira" else "athan_${sound}_opening"
            val res = context.resources.getIdentifier(name, "raw", context.packageName)
            return if (sound == "silent" || res == 0) null
            else Uri.parse("android.resource://${context.packageName}/$res")
        }

        /** Reminder alarms have their own action and address, so their ids never meet prayer ids. */
        private fun alarmBase(context: Context, id: Int, reminder: Boolean) =
            Intent(context, PrayerAlarmReceiver::class.java)
                .setAction(if (reminder) REMINDER_ACTION else ALERT_ACTION)
                .setData(Uri.parse(if (reminder) "mathani-khatma://reminder/$id" else "mathani-prayer://alert/$id"))

        private fun alarmIntent(context: Context, id: Int, generation: Long, reminder: Boolean) =
            PendingIntent.getBroadcast(context, id, alarmBase(context, id, reminder)
                .putExtra("id", id).putExtra("generation", generation),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        /** One alarm per alert; exact when allowed, otherwise Android may delay it (FR-021). */
        fun install(context: Context, store: PrayerAlarmStore, nowMs: Long, reminder: Boolean = false): Int {
            val alarms = context.getSystemService(AlarmManager::class.java)
            val generation = store.generation()
            val future = store.future(nowMs)
            future.forEach {
                val pending = alarmIntent(context, it.id, generation, reminder)
                if (exact(context)) alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, it.atUtcMs, pending)
                else alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, it.atUtcMs, pending)
            }
            return future.size
        }

        fun cancel(context: Context, ids: Collection<Int>, reminder: Boolean = false) {
            val alarms = context.getSystemService(AlarmManager::class.java)
            ids.forEach { id ->
                PendingIntent.getBroadcast(context, id, alarmBase(context, id, reminder),
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)?.let { alarms.cancel(it); it.cancel() }
            }
        }

        /** The reminder's channel: the phone's default sound and importance (specs/014 FR-026). */
        fun ensureReminderChannel(context: Context, name: String) {
            if (Build.VERSION.SDK_INT < 26) return
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(REMINDER_CHANNEL, name, NotificationManager.IMPORTANCE_DEFAULT))
        }

        /** The announcements channel: the phone's default sound and importance (specs/015 R8). */
        fun ensureAnnouncementChannel(context: Context, name: String) {
            if (Build.VERSION.SDK_INT < 26) return
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(ANNOUNCEMENT_CHANNEL, name, NotificationManager.IMPORTANCE_DEFAULT))
        }

        /** An announcement that arrived while the app is open, which FCM does not show itself. Silent,
         * so reading and recitation are not interrupted (spec US4 scenario 2). */
        fun postAnnouncement(context: Context, id: Int, title: String, body: String, link: String?) {
            val open = PendingIntent.getActivity(context, id,
                Intent(context, MainActivity::class.java).setAction(OPEN_ACTION)
                    .putExtra("id", id).putExtra("kind", "announcement").putExtra("link", link)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val notification = NotificationCompat.Builder(context, ANNOUNCEMENT_CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_recitation)
                .setContentTitle(title).setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setContentIntent(open).setSilent(true).setAutoCancel(true).build()
            context.getSystemService(NotificationManager::class.java).notify(ANNOUNCEMENT_TAG, id, notification)
        }

        /** Channel sounds are fixed once created, so each sound has its own channel. The reader's
         * channel settings are never overridden. */
        fun ensureChannels(context: Context, names: Map<String, String>) {
            if (Build.VERSION.SDK_INT < 26) return
            val manager = context.getSystemService(NotificationManager::class.java)
            val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
            names.forEach { (sound, name) ->
                when (sound) {
                    "stop" -> Unit
                    "qiyam" -> manager.createNotificationChannel(
                        NotificationChannel(QIYAM_CHANNEL, name, NotificationManager.IMPORTANCE_HIGH).apply {
                            setSound(soundUri(context, "tone"), attributes)
                        })
                    "playback" -> manager.createNotificationChannel(
                        NotificationChannel(PLAYBACK_CHANNEL, name, NotificationManager.IMPORTANCE_LOW).apply {
                            setSound(null, null)
                        })
                    else -> manager.createNotificationChannel(
                        NotificationChannel(channelId(sound), name, NotificationManager.IMPORTANCE_HIGH).apply {
                            setSound(soundUri(context, sound), if (sound == "silent") null else attributes)
                            if (sound == "silent") enableVibration(false)
                        })
                }
            }
            // The first draft's channels.
            manager.deleteNotificationChannel("mathani.prayer.default.v1")
            manager.deleteNotificationChannel("mathani.prayer.qiyam.v1")
            // The generated-chime channels, before the takbira.
            manager.deleteNotificationChannel("prayer_qiyam_v1")
            manager.deleteNotificationChannel("prayer_tone_v1")
        }

        /** Texts the athan service shows, in the app's language, saved with each refill. */
        fun saveChannelNames(context: Context, names: Map<String, String>) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString("playbackChannel", names["playback"]).putString("stopLabel", names["stop"]).apply()
        }

        fun playbackChannelName(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("playbackChannel", null) ?: "Athan"

        fun stopLabel(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("stopLabel", null) ?: "Stop"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "app.mathani/prayer_notifications")
        events = channel
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        if (events === channel) events = null
    }

    private fun status(): Map<String, Any?> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val permission = when {
            granted(context) -> "granted"
            Build.VERSION.SDK_INT >= 33 && !prefs.getBoolean("asked", false) -> "notDetermined"
            else -> "denied"
        }
        return mapOf("notifications" to (permission == "granted"), "permission" to permission,
            "exactAlarms" to if (Build.VERSION.SDK_INT >= 31) exact(context) else null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            val store = PrayerAlarmStore(context)
            when (call.method) {
                "status" -> result.success(status())
                "requestPermission" -> {
                    val current = activity
                    if (Build.VERSION.SDK_INT >= 33 && current != null && !granted(context) && permissionResult == null) {
                        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean("asked", true).apply()
                        permissionResult = result
                        ActivityCompat.requestPermissions(current, arrayOf(Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST)
                    } else result.success(status())
                }
                "openSettings" -> {
                    val exactSettings = call.argument<Boolean>("exactAlarms") == true && Build.VERSION.SDK_INT >= 31
                    val intent = if (exactSettings) Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${context.packageName}"))
                        else Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }
                "replace" -> {
                    val generation = call.argument<Number>("generation")!!.toLong()
                    val alerts = call.argument<List<Map<String, Any?>>>("alerts")!!.map {
                        PrayerAlert((it["id"] as Number).toInt(), it["kind"] as String, (it["atUtcMs"] as Number).toLong(),
                            it["title"] as String, it["body"] as String, it["sound"] as String,
                            it["full"] == true, it["fullPath"] as String?)
                    }
                    val names = call.argument<Map<String, String>>("channels") ?: emptyMap()
                    ensureChannels(context, names)
                    saveChannelNames(context, names)
                    cancel(context, store.replace(generation, alerts))
                    result.success(install(context, store, System.currentTimeMillis()))
                }
                "cancelAll" -> { cancel(context, store.clear()); result.success(null) }
                "ensureAnnouncementChannel" -> {
                    ensureAnnouncementChannel(context, call.argument<String>("name") ?: "Announcements")
                    result.success(null)
                }
                "showAnnouncement" -> {
                    ensureAnnouncementChannel(context, call.argument<String>("channelName") ?: "Announcements")
                    if (granted(context)) postAnnouncement(context, call.argument<Number>("id")!!.toInt(),
                        call.argument<String>("title") ?: "", call.argument<String>("body") ?: "",
                        call.argument<String>("link"))
                    result.success(null)
                }
                // The khatma reminders (specs/014): a second store file, the `wird` kind.
                "replaceReminders" -> {
                    val reminders = PrayerAlarmStore(context, PrayerAlarmStore.REMINDER_FILE)
                    val generation = call.argument<Number>("generation")!!.toLong()
                    val alerts = call.argument<List<Map<String, Any?>>>("alerts")!!.map {
                        PrayerAlert((it["id"] as Number).toInt(), "wird", (it["atUtcMs"] as Number).toLong(),
                            it["title"] as String, it["body"] as String, "default")
                    }
                    ensureReminderChannel(context, call.argument<String>("channelName") ?: "Daily reminder")
                    cancel(context, reminders.replace(generation, alerts), reminder = true)
                    result.success(install(context, reminders, System.currentTimeMillis(), reminder = true))
                }
                "cancelReminders" -> {
                    cancel(context, PrayerAlarmStore(context, PrayerAlarmStore.REMINDER_FILE).clear(), reminder = true)
                    result.success(null)
                }
                "clearReminders" -> {
                    val manager = context.getSystemService(NotificationManager::class.java)
                    call.argument<List<Number>>("ids")?.forEach { manager.cancel(REMINDER_TAG, it.toInt()) }
                    result.success(null)
                }
                "takeOpened" -> { result.success(pendingOpen); pendingOpen = null }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("prayerAlerts", error.message, null)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        permissionResult?.success(status()); permissionResult = null
        return true
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding; activity = binding.activity; binding.addRequestPermissionsResultListener(this)
    }
    override fun onDetachedFromActivityForConfigChanges() = detach()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromActivity() = detach()
    private fun detach() {
        binding?.removeRequestPermissionsResultListener(this); binding = null; activity = null
        permissionResult?.success(status()); permissionResult = null
    }
}

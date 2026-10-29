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

/** Owns short OS alerts only. Full/media playback remains disabled pending G01. */
class PrayerNotificationsPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var permissionResult: MethodChannel.Result? = null
    companion object {
        const val DEFAULT_CHANNEL = "mathani.prayer.default.v1"
        const val QIYAM_CHANNEL = "mathani.prayer.qiyam.v1"
        const val TAG_PREFIX = "mathani.prayer."
        private const val PERMISSION_REQUEST = 7413
        private var pendingOpen = false
        private var openChannel: MethodChannel? = null
        fun noteOpenIntent(intent: Intent?) {
            if (intent?.action?.startsWith("app.mathani.OPEN_PRAYER.") != true) return
            pendingOpen = true
            openChannel?.invokeMethod("notificationOpen", null)
        }
        fun supported(event: PrayerAlarmEvent) = event.mode == "opening" &&
            if (event.kind == "qiyam") event.assetId in setOf("qiyam_tone", "qiyam_tone_inexact")
            else event.assetId in setOf("system_default", "system_default_inexact")
        fun register(engine: FlutterEngine) {
            if (!engine.plugins.has(PrayerNotificationsPlugin::class.java)) engine.plugins.add(PrayerNotificationsPlugin())
        }
        fun exact(context: Context) = Build.VERSION.SDK_INT < 31 || context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
        fun granted(context: Context) = NotificationManagerCompat.from(context).areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)
        fun alarmIntent(context: Context, event: PrayerAlarmEvent) = Intent(context, PrayerAlarmReceiver::class.java)
            .setAction("app.mathani.PRAYER.${event.generation}.${event.eventId}")
            .putExtra("eventId", event.eventId).putExtra("generation", event.generation)
        fun install(context: Context, events: List<PrayerAlarmEvent>) {
            val alarms = context.getSystemService(AlarmManager::class.java)
            val precise = exact(context)
            events.forEach { event ->
                if (!supported(event)) return@forEach
                val pending = PendingIntent.getBroadcast(context, 0, alarmIntent(context, event), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                // Inexact installation is permitted only for an acknowledged inexact asset marker.
                if (precise) alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, event.dueAtMs, pending)
                else if (event.assetId.endsWith("_inexact")) alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, event.dueAtMs, pending)
                else throw SecurityException("Exact alarm access unavailable")
            }
        }
        fun cancelAlarms(context: Context, events: List<PrayerAlarmEvent>) {
            val alarms = context.getSystemService(AlarmManager::class.java)
            events.forEach { event -> PendingIntent.getBroadcast(context, 0, alarmIntent(context, event),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)?.let { alarms.cancel(it); it.cancel() } }
        }
        fun cancelShown(context: Context) {
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.activeNotifications.filter { it.tag?.startsWith(TAG_PREFIX) == true }.forEach { manager.cancel(it.tag, it.id) }
        }
        fun ensureChannels(context: Context, defaultName: String, qiyamName: String) {
            if (Build.VERSION.SDK_INT < 26) return
            val manager = context.getSystemService(NotificationManager::class.java)
            val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build()
            manager.createNotificationChannel(NotificationChannel(DEFAULT_CHANNEL, defaultName, NotificationManager.IMPORTANCE_HIGH))
            manager.createNotificationChannel(NotificationChannel(QIYAM_CHANNEL, qiyamName, NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(Uri.parse("android.resource://${context.packageName}/raw/qiyam_tone"), attributes)
            })
        }
    }
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "app.mathani/prayer_notifications")
        openChannel = channel
        channel.setMethodCallHandler(this)
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        if (openChannel === channel) openChannel = null
    }
    private fun capabilities(): Map<String, Any> {
        val manager = context.getSystemService(NotificationManager::class.java)
        fun blocked(id: String): Boolean = Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(id)?.let {
            it.importance == NotificationManager.IMPORTANCE_NONE || it.sound == null ||
                it.group?.let { group -> Build.VERSION.SDK_INT >= 28 && manager.getNotificationChannelGroup(group)?.isBlocked == true } == true
        } == true
        return mapOf("permissionStatus" to if (granted(context)) "granted" else "denied", "exactAlarmAccess" to exact(context),
            "dailyRestricted" to blocked(DEFAULT_CHANNEL), "qiyamRestricted" to blocked(QIYAM_CHANNEL))
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            val store = PrayerAlarmStore(context)
            when (call.method) {
                "capabilities" -> result.success(capabilities())
                "takeNotificationOpen" -> { val opened = pendingOpen; pendingOpen = false; result.success(opened) }
                "requestAuthorization" -> {
                    val current = activity
                    if (Build.VERSION.SDK_INT >= 33 && current != null && !granted(context)) {
                        check(permissionResult == null)
                        permissionResult = result
                        ActivityCompat.requestPermissions(current, arrayOf(Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST)
                    } else result.success(capabilities())
                }
                "openSettings", "requestExactAccess" -> {
                    val exactSettings = call.method == "requestExactAccess" && Build.VERSION.SDK_INT >= 31
                    val intent = if (exactSettings) Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${context.packageName}"))
                        else Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); result.success(null)
                }
                "replace" -> {
                    check(granted(context))
                    val generation = call.argument<Number>("generation")!!.toLong()
                    val raw = call.argument<List<Map<String, Any>>>("events")!!
                    require(raw.size <= 192)
                    val events = raw.map { item ->
                        val asset = item["assetId"] as String
                        require(asset in setOf("system_default", "qiyam_tone", "system_default_inexact", "qiyam_tone_inexact"))
                        PrayerAlarmEvent(item["eventId"] as String, item["locationId"] as String, generation,
                            (item["dueAtMs"] as Number).toLong(), (item["expiresAtMs"] as Number).toLong(),
                            item["kind"] as String, asset, "opening", item["title"] as String, item["body"] as String).also {
                            require((it.kind == "qiyam") == asset.startsWith("qiyam_tone"))
                        }
                    }
                    require(exact(context) || events.all { it.assetId.endsWith("_inexact") })
                    val now = System.currentTimeMillis()
                    val old = store.future(now)
                    store.replace(generation, events, now)
                    cancelAlarms(context, old)
                    ensureChannels(context, call.argument<String>("dailyChannelName")!!, call.argument<String>("qiyamChannelName")!!)
                    install(context, store.future(System.currentTimeMillis()))
                    result.success(pending(store))
                }
                "pending" -> result.success(pending(store))
                "cancelAll" -> {
                    val events = store.future(System.currentTimeMillis())
                    store.clearPending(); cancelAlarms(context, events); cancelShown(context); result.success(null)
                }
                "stop" -> { cancelShown(context); result.success(null) }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("notificationsUnavailable", "Prayer notifications need attention", null)
        }
    }
    private fun pending(store: PrayerAlarmStore) = store.future(System.currentTimeMillis()).filter {
        supported(it) && (exact(context) || it.assetId.endsWith("_inexact")) &&
          PendingIntent.getBroadcast(context, 0, alarmIntent(context,it), PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE) != null
    }.map {
        mapOf("eventId" to it.eventId, "generation" to it.generation, "dueAtMs" to it.dueAtMs)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        permissionResult?.success(capabilities()); permissionResult = null; return true
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding; activity = binding.activity; binding.addRequestPermissionsResultListener(this)
    }
    override fun onDetachedFromActivityForConfigChanges() = detach()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromActivity() = detach()
    private fun detach() {
        binding?.removeRequestPermissionsResultListener(this); binding = null; activity = null
        permissionResult?.error("activityUnavailable", "Open Mathani to allow notifications", null); permissionResult = null
    }
}

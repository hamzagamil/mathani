package app.mathani.mathani

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import androidx.core.app.NotificationCompat
import java.util.concurrent.Executors

/** No Flutter/media start. OS-owned short sounds only; validate the protected token. */
class PrayerAlarmReceiver : BroadcastReceiver() {
    companion object { private val executor = Executors.newSingleThreadExecutor() }
    override fun onReceive(context: Context, intent: Intent) {
        val work = goAsync()
        executor.execute {
            try {
                val store = PrayerAlarmStore(context)
                val now = System.currentTimeMillis()
                val id = intent.getStringExtra("eventId")
                if (id == null) {
                    if (intent.action in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_USER_UNLOCKED,
                        Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_MY_PACKAGE_REPLACED,
                        "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED")) {
                        if (PrayerNotificationsPlugin.granted(context)) PrayerNotificationsPlugin.install(context, store.future(now))
                    }
                    return@execute
                }
                val generation = intent.getLongExtra("generation", -1)
                val event = store.event(id, generation) ?: return@execute
                if (!PrayerNotificationsPlugin.granted(context) || !PrayerNotificationsPlugin.supported(event)) return@execute
                store.deliverFallback(id, generation, now) {
                if (System.currentTimeMillis() > event.expiresAtMs) return@deliverFallback
                val qiyam = event.kind == "qiyam"
                val channel = if (qiyam) PrayerNotificationsPlugin.QIYAM_CHANNEL else PrayerNotificationsPlugin.DEFAULT_CHANNEL
                val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java)
                    .setAction("app.mathani.OPEN_PRAYER.$id").addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                val sound = if (qiyam) Uri.parse("android.resource://${context.packageName}/raw/qiyam_tone")
                    else RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                val notification = NotificationCompat.Builder(context, channel).setSmallIcon(R.drawable.ic_stat_recitation)
                    .setContentTitle(event.title).setContentText(event.body).setContentIntent(open)
                    .setPriority(NotificationCompat.PRIORITY_HIGH).setSound(sound).setAutoCancel(true)
                    .setTimeoutAfter(60_000).build()
                context.getSystemService(NotificationManager::class.java).notify(PrayerNotificationsPlugin.TAG_PREFIX + id, 0, notification)
                }
            } catch (error: Exception) {
                // Locked or damaged ciphertext fails closed. Retry future alarms after unlock.
            } finally { work.finish() }
        }
    }
}

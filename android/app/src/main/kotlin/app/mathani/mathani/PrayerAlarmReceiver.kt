package app.mathani.mathani

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.io.File
import java.util.concurrent.Executors

/** Posts a due prayer alert, or starts the full athan, without starting Flutter. Restores future
 * alarms after a reboot or a clock change (specs/009 contracts › Android). */
class PrayerAlarmReceiver : BroadcastReceiver() {
    companion object {
        private val executor = Executors.newSingleThreadExecutor()

        fun openIntent(context: Context, alert: PrayerAlert): PendingIntent = PendingIntent.getActivity(
            context, alert.id,
            Intent(context, MainActivity::class.java).setAction(PrayerNotificationsPlugin.OPEN_ACTION)
                .putExtra("id", alert.id).putExtra("kind", alert.kind)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        fun post(context: Context, alert: PrayerAlert) {
            val notification = NotificationCompat.Builder(context, PrayerNotificationsPlugin.soundChannel(alert))
                .setSmallIcon(R.drawable.ic_stat_recitation)
                .setContentTitle(alert.title).setContentText(alert.body)
                .setContentIntent(openIntent(context, alert))
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setSound(PrayerNotificationsPlugin.soundUri(context, if (alert.kind == "qiyam") "tone" else alert.sound))
                .setAutoCancel(true).build()
            context.getSystemService(NotificationManager::class.java).notify("mathani.prayer", alert.id, notification)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val work = goAsync()
        executor.execute {
            try {
                val store = PrayerAlarmStore(context)
                val now = System.currentTimeMillis()
                if (intent.action != PrayerNotificationsPlugin.ALERT_ACTION) {
                    // Boot, unlock, update, clock or exact-alarm changes: future alerts only.
                    PrayerNotificationsPlugin.install(context, store, now)
                    return@execute
                }
                val id = intent.getIntExtra("id", -1)
                val alert = store.get(id)
                // The athan plays only when the ringer is on, as the phone's own alert sound would.
                val ringerOn = context.getSystemService(AudioManager::class.java).ringerMode == AudioManager.RINGER_MODE_NORMAL
                val action = PrayerAlertRules.decide(
                    alert, intent.getLongExtra("generation", -1), store.generation(), now,
                    fullFileExists = alert?.fullPath?.let { File(it).isFile } == true,
                    canStartFull = PrayerNotificationsPlugin.exact(context) && ringerOn,
                )
                if (action == AlertAction.IGNORE || alert == null || !store.remove(id)) return@execute
                when (action) {
                    AlertAction.PLAY_FULL -> if (!startFull(context, alert)) post(context, alert)
                    AlertAction.POST -> post(context, alert)
                    else -> Unit
                }
            } catch (error: Exception) {
                // A broken store must not crash the app; the next refill rebuilds it.
            } finally { work.finish() }
        }
    }

    private fun startFull(context: Context, alert: PrayerAlert): Boolean = try {
        ContextCompat.startForegroundService(context, Intent(context, AthanPlaybackService::class.java)
            .putExtra("id", alert.id).putExtra("kind", alert.kind).putExtra("title", alert.title)
            .putExtra("body", alert.body).putExtra("path", alert.fullPath).putExtra("sound", alert.sound))
        true
    } catch (error: Exception) {
        false // e.g. ForegroundServiceStartNotAllowedException: the opening alert is posted instead
    }
}

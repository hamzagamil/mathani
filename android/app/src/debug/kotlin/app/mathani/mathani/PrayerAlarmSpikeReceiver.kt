package app.mathani.mathani

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/** Debug-only G01 receiver. Alarms carry only an opaque token and generation. */
class PrayerAlarmSpikeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("eventId") ?: return
        val generation = intent.getLongExtra("generation", -1)
        if (generation < 0) return
        val pending = goAsync()
        PrayerMediaBridge.deliver(context, id, generation) { started ->
            try {
                if (!started && PrayerAlarmStore(context).claimFallback(id, generation, System.currentTimeMillis())) {
                    if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return@deliver
                    val manager = context.getSystemService(NotificationManager::class.java)
                    val sound = Uri.parse("android.resource://${context.packageName}/${R.raw.prayer_spike_tone}")
                    val channelId = "mathani.prayer.spike.fallback"
                    if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(channelId, "Prayer startup test", NotificationManager.IMPORTANCE_HIGH).apply {
                        setSound(sound, AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build())
                    })
                    manager.notify(id.hashCode(), NotificationCompat.Builder(context, channelId)
                        .setSmallIcon(R.drawable.ic_stat_recitation).setContentTitle("Prayer startup test fallback")
                        .setContentText("Generated test tone; app audio did not acknowledge startup")
                        .setSound(sound).setAutoCancel(true).build())
                }
            } finally { pending.finish() }
        }
    }
}

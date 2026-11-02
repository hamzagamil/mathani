package app.mathani.mathani

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/** The full athan with the phone locked or the app closed (specs/009 research R9). Started by the
 * exact alarm, no Flutter engine needed. It holds audio focus, so Quran recitation pauses and
 * does not resume by itself; Stop is in the notification (FR-024–FR-026). */
class AthanPlaybackService : Service(), AudioManager.OnAudioFocusChangeListener {
    companion object {
        private const val STOP = "app.mathani.ATHAN_STOP"
        private const val NOTIFICATION_ID = 0x41544841
    }

    private var player: MediaPlayer? = null
    private var focus: AudioFocusRequest? = null
    private val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null || intent.action == STOP) {
            finish()
            return START_NOT_STICKY
        }
        val id = intent.getIntExtra("id", 0)
        val title = intent.getStringExtra("title") ?: ""
        val body = intent.getStringExtra("body") ?: ""
        startForeground(id, title, body, intent.getStringExtra("kind") ?: "fajr")
        release()
        try {
            val audio = getSystemService(AudioManager::class.java)
            val granted = if (Build.VERSION.SDK_INT >= 26) {
                val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(attributes).setOnAudioFocusChangeListener(this).build()
                focus = request
                audio.requestAudioFocus(request)
            } else {
                @Suppress("DEPRECATION")
                audio.requestAudioFocus(this, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN)
            }
            check(granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
            player = MediaPlayer().apply {
                setAudioAttributes(attributes)
                setDataSource(intent.getStringExtra("path"))
                setOnCompletionListener { finish() }
                setOnErrorListener { _, _, _ -> finish(); true }
                prepare()
                start()
            }
            PrayerNotificationsPlugin.emit("athanStarted")
        } catch (error: Exception) {
            finish()
            // Unplayable file or no audio focus: the opening alert instead.
            runCatching {
                PrayerAlarmReceiver.post(this, PrayerAlert(id, intent.getStringExtra("kind") ?: "fajr", 1,
                    title.ifEmpty { "-" }, body, intent.getStringExtra("sound") ?: "tone"))
            }
        }
        return START_NOT_STICKY
    }

    private fun startForeground(id: Int, title: String, body: String, kind: String) {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(PrayerNotificationsPlugin.PLAYBACK_CHANNEL) == null) {
            manager.createNotificationChannel(NotificationChannel(PrayerNotificationsPlugin.PLAYBACK_CHANNEL,
                PrayerNotificationsPlugin.playbackChannelName(this), NotificationManager.IMPORTANCE_LOW).apply { setSound(null, null) })
        }
        val stop = PendingIntent.getService(this, 0, Intent(this, AthanPlaybackService::class.java).setAction(STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(this, PrayerNotificationsPlugin.PLAYBACK_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_recitation)
            .setContentTitle(title).setContentText(body)
            .setContentIntent(PrayerAlarmReceiver.openIntent(this, PrayerAlert(id, kind, 1, title.ifEmpty { "-" }, body, "tone")))
            .setDeleteIntent(stop)
            .addAction(0, stopLabel(), stop)
            .setOngoing(true).setCategory(NotificationCompat.CATEGORY_ALARM).build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else startForeground(NOTIFICATION_ID, notification)
    }

    /** The Stop label in the app's language, saved by Dart with the channel names. */
    private fun stopLabel() = PrayerNotificationsPlugin.stopLabel(this)

    override fun onAudioFocusChange(change: Int) {
        if (change < 0) finish()
    }

    private fun release() {
        player?.release()
        player = null
        val audio = getSystemService(AudioManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) focus?.let { audio.abandonAudioFocusRequest(it) }
        else @Suppress("DEPRECATION") audio.abandonAudioFocus(this)
        focus = null
    }

    private fun finish() {
        release()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        release()
        super.onDestroy()
    }
}

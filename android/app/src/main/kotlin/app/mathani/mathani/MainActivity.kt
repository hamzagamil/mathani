package app.mathani.mathani

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// AudioServiceActivity shares its Flutter engine with the recitation service, so playback and
/// the lock-screen controls keep working while the app is in the background (specs/004 US3).
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DeviceChannel.register(this, flutterEngine)
        PrayerNotificationsPlugin.register(flutterEngine)
        PrayerNotificationsPlugin.noteOpenIntent(intent)
        PrayerMediaBridge.register(flutterEngine, this)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        PrayerNotificationsPlugin.noteOpenIntent(intent)
    }
}

/// Network type and free storage for recitation downloads (specs/004, research R8); device
/// support, the Settings link and the mistake tone for memorization (specs/006, R12, R15).
object DeviceChannel {
    fun register(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "app.mathani/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "networkState" -> result.success(networkState(context))
                    "freeBytes" -> result.success(StatFs(context.filesDir.path).availableBytes)
                    "excludeFromBackup" -> result.success(null) // iOS only
                    "deviceSupport" -> result.success(deviceSupport(context))
                    "openAppSettings" -> {
                        openAppSettings(context)
                        result.success(null)
                    }
                    "playMistakeTone" -> {
                        playMistakeTone()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun deviceSupport(context: Context): Map<String, Any> {
        val memory = ActivityManager.MemoryInfo()
        context.getSystemService(ActivityManager::class.java)?.getMemoryInfo(memory)
        return mapOf(
            "arm64" to Build.SUPPORTED_64_BIT_ABIS.isNotEmpty(),
            "ramBytes" to memory.totalMem,
        )
    }

    private fun openAppSettings(context: Context) {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", context.packageName, null))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    /// On the notification stream, so a silent or vibrating ringer mutes it (research R12).
    private fun playMistakeTone() {
        val tone = try {
            ToneGenerator(AudioManager.STREAM_NOTIFICATION, 50)
        } catch (e: RuntimeException) {
            return // no tone generator available
        }
        tone.startTone(ToneGenerator.TONE_PROP_BEEP, 120)
        Handler(Looper.getMainLooper()).postDelayed({ tone.release() }, 300)
    }

    private fun networkState(context: Context): String {
        val manager = context.getSystemService(ConnectivityManager::class.java) ?: return "none"
        val capabilities = manager.getNetworkCapabilities(manager.activeNetwork) ?: return "none"
        if (!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)) return "none"
        return if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)) {
            "unmetered"
        } else {
            "metered"
        }
    }
}

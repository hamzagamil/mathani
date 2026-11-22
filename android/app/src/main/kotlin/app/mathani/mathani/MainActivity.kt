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
import app.mathani.mathani.widgets.WidgetsPlugin
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
        WidgetsPlugin.register(flutterEngine)
        PrayerNotificationsPlugin.noteOpenIntent(intent)
        DeviceChannel.noteLink(intent, launch = true)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        PrayerNotificationsPlugin.noteOpenIntent(intent)
        DeviceChannel.noteLink(intent, launch = false)
    }
}

/** The hosts whose links open the app (AndroidManifest.xml). */
private val LINK_HOSTS = setOf("get.mthani.app", "mthani.app", "www.mthani.app")

/** Widget taps open the app with these links, in explicit intents only (specs/017). */
private const val WIDGET_SCHEME = "mathani-widget"

/// Network type and free storage for recitation downloads (specs/004, research R8); device
/// support, the Settings link and the mistake tone for memorization (specs/006, R12, R15).
object DeviceChannel {
    private var channel: MethodChannel? = null
    private var pendingLink: String? = null

    /** A group khatma link (specs/014 research R16) or a widget tap (specs/017 research R8) the
     * app was opened with, or that arrived while it runs: handed to Dart once by `takeLink`, or
     * sent as a `link` event. Any other Mathani link only opens the app. */
    fun noteLink(intent: Intent?, launch: Boolean) {
        val data = intent?.data ?: return
        if (intent.action != Intent.ACTION_VIEW) return
        val group = data.host?.lowercase() in LINK_HOSTS && data.path?.startsWith("/k/") == true
        if (!group && data.scheme != WIDGET_SCHEME) return
        val link = data.toString()
        val events = channel
        // At launch Dart is not listening yet: it asks with takeLink after the first frame.
        if (launch || events == null) pendingLink = link else events.invokeMethod("link", link)
    }

    fun register(context: Context, engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "app.mathani/device")
        channel!!
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeLink" -> { result.success(pendingLink); pendingLink = null }
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

package app.mathani.mathani

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.StatFs
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// AudioServiceActivity shares its Flutter engine with the recitation service, so playback and
/// the lock-screen controls keep working while the app is in the background (specs/004 US3).
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DeviceChannel.register(this, flutterEngine)
    }
}

/// Network type and free storage for recitation downloads (specs/004, research R8).
object DeviceChannel {
    fun register(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "app.mathani/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "networkState" -> result.success(networkState(context))
                    "freeBytes" -> result.success(StatFs(context.filesDir.path).availableBytes)
                    "excludeFromBackup" -> result.success(null) // iOS only
                    else -> result.notImplemented()
                }
            }
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

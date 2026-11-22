package app.mathani.mathani.widgets

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** The `app.mathani/widgets` channel (specs/017 contracts/widget-snapshot.md). */
class WidgetsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    companion object {
        fun register(engine: FlutterEngine) {
            if (!engine.plugins.has(WidgetsPlugin::class.java)) engine.plugins.add(WidgetsPlugin())
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "app.mathani/widgets").also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = context ?: return result.error("detached", null, null)
        when (call.method) {
            "update" -> {
                val snapshot = call.argument<String>("snapshot")
                if (snapshot == null || Snapshot.parse(snapshot) == null) {
                    return result.error("invalid", "Unreadable widget snapshot", null)
                }
                if (SnapshotStore(context).put(snapshot)) WidgetRefresher.refreshAll(context)
                call.argument<String>("watch")?.let { WearSync.send(context, it) }
                result.success(null)
            }
            "placed" -> result.success(buildList {
                if (WidgetRefresher.ids(context, PrayerWidgetProvider::class.java).isNotEmpty()) add("prayer")
                if (WidgetRefresher.ids(context, QuranWidgetProvider::class.java).isNotEmpty()) add("quran")
            })
            "clear" -> {
                SnapshotStore(context).clear()
                WidgetRefresher.refreshAll(context)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
